#------------------------------------------------------------------------------
# Dense evaluation of TLExpr to LabeledTensor (no generalized einsum)
#------------------------------------------------------------------------------
using Dictionaries

@inline _relu(x) = ifelse(x > zero(x), x, zero(x))

"""Evaluate a tutorial-style expression to a dense `LabeledTensor`.
   Evaluate a `TLExpr` to a `LabeledTensor`.

Use `inputs` to supply predicate tensors, and `config` to select semantics.
"""
function eval_dense(expr::TLExpr, ctx::CompilerContext;
                    inputs::Dictionary{Symbol,Any}=Dictionary{Symbol,Any}(),
                    config::CompilationConfig=soft_differentiable(),
                    consts=nothing,
                    backend=:auto,
                    planner=GreedyPlanner())

    env = Dictionary{Symbol,Symbol}() # var => domain
    be = resolve_backend(backend)
    return _eval(expr, ctx, inputs, config, consts, env, be, planner)
end

function _input_array(inputs::Dictionary{Symbol,Any}, pred::Symbol)
    _has(inputs, pred) || throw(ArgumentError("missing input tensor for predicate $pred"))
    v = inputs[pred]
    v isa LabeledTensor && return (v::LabeledTensor).data
    v isa AbstractArray && return v
    throw(ArgumentError("input for $pred must be AbstractArray or LabeledTensor"))
end

function _check_pred_shape!(ctx::CompilerContext, pred::Symbol, A::AbstractArray)
    sig = _pred_sig(ctx, pred)
    ndims(A) == length(sig) || throw(DimensionMismatch("predicate $pred arity mismatch: expected $(length(sig)), got $(ndims(A))"))
    for i in 1:length(sig)
        dom = sig[i]
        n = _domain_size(ctx, dom)
        size(A, i) == n || throw(DimensionMismatch("predicate $pred dimension $i mismatch: expected $n for domain $dom, got $(size(A,i))"))
    end
    return sig
end

function _const_index(consts, dom::Symbol, c::Symbol)
    consts === nothing && throw(ArgumentError("constant $c used but no consts mapping provided"))
    _has(consts, dom) || throw(ArgumentError("no constants mapping for domain $dom"))
    m = consts[dom]
    _has(m, c) || throw(ArgumentError("no index for constant $c in domain $dom"))
    return m[c]
end

function _pred_tensor(expr::Pred, ctx::CompilerContext, inputs, consts, env)
    A = _input_array(inputs, expr.name)
    sig = _check_pred_shape!(ctx, expr.name, A)

    axes = Symbol[]
    data = A
    @inbounds for (i, term) in enumerate(expr.args)
        dom = sig[i]
        if term isa VarT
            v = (term::VarT).name
            if _has(env, v)
                env[v] == dom || throw(ArgumentError("variable $v domain mismatch: $(env[v]) vs $dom"))
            else
                set!(env, v, dom)
            end
            push!(axes, v)
        else
            idx = _const_index(consts, dom, (term::ConstT).name)
            @views data = selectdim(data, i, idx)
        end
    end

    return LabeledTensor(data, axes)
end

@inline function _align_pair(a::LabeledTensor, b::LabeledTensor)
    check_compatible!(a, b)
    axes = copy(a.axes)
    for ax in b.axes
        ax in axes || push!(axes, ax)
    end
    Aa = _align_to_axes(a, axes)
    Bb = _align_to_axes(b, axes)
    return axes, Aa, Bb
end

function _and_apply(cfg::CompilationConfig, Aa, Bb)
    k = _and_kind(cfg)
    if k === :prod
        return Aa .* Bb
    elseif k === :min
        return min.(Aa, Bb)
    elseif k === :luk_and
        T = promote_type(eltype(Aa), eltype(Bb))
        return max.(zero(T), Aa .+ Bb .- _one(T))
    elseif k === :prob_and
        return Aa .+ Bb .- (Aa .* Bb)
    else
        error("unknown AND kind $k")
    end
end

function _or_apply(cfg::CompilationConfig, Aa, Bb)
    k = _or_kind(cfg)
    if k === :max
        return max.(Aa, Bb)
    elseif k === :prob_or
        return Aa .+ Bb .- (Aa .* Bb)
    elseif k === :luk_or
        T = promote_type(eltype(Aa), eltype(Bb))
        return min.(_one(T), Aa .+ Bb)
    else
        error("unknown OR kind $k")
    end
end

function _not_apply(A)
    T = eltype(A)
    return _one(T) .- A
end

function _imply_apply(cfg::CompilationConfig, Aa, Bb)
    k = _imply_kind(cfg)
    if k === :relu_diff
        return _relu.(Bb .- Aa)
    elseif k === :godel
        T = promote_type(eltype(Aa), eltype(Bb))
        return ifelse.(Aa .<= Bb, _one(T), Bb)
    else
        return _or_apply(cfg, _not_apply(Aa), Bb)
    end
end

function _reduce_max(t::LabeledTensor, ax::Symbol)
    p = findfirst(==(ax), t.axes)
    p === nothing && return t
    data = maximum(t.data, dims=p)
    data2 = dropdims(data, dims=p)
    axes2 = [a for a in t.axes if a != ax]
    return LabeledTensor(data2, axes2)
end

function _reduce_exists(cfg::CompilationConfig, t::LabeledTensor, ax::Symbol)
    kind = _exists_reduce_kind(cfg)
    if kind === :sum
        return sum_out_dense(t, ax)
    elseif kind === :mean
        p = findfirst(==(ax), t.axes)
        p === nothing && return t
        k = size(t.data, p)
        s = sum_out_dense(t, ax)
        return LabeledTensor(s.data ./ k, s.axes)
    else
        return _reduce_max(t, ax)
    end
end

function _eval(expr::TLExpr, ctx::CompilerContext, inputs, cfg, consts, env, backend::DenseBackend, planner)::LabeledTensor
    if expr isa Pred
        return _pred_tensor(expr::Pred, ctx, inputs, consts, env)
    elseif expr isa AndExpr
        a = _eval((expr::AndExpr).a, ctx, inputs, cfg, consts, env, backend, planner)
        b = _eval((expr::AndExpr).b, ctx, inputs, cfg, consts, env, backend, planner)
        axes, Aa, Bb = _align_pair(a, b)
        return LabeledTensor(_and_apply(cfg, Aa, Bb), axes)
    elseif expr isa OrExpr
        a = _eval((expr::OrExpr).a, ctx, inputs, cfg, consts, env, backend, planner)
        b = _eval((expr::OrExpr).b, ctx, inputs, cfg, consts, env, backend, planner)
        axes, Aa, Bb = _align_pair(a, b)
        return LabeledTensor(_or_apply(cfg, Aa, Bb), axes)
    elseif expr isa NotExpr
        a = _eval((expr::NotExpr).x, ctx, inputs, cfg, consts, env, backend, planner)
        return LabeledTensor(_not_apply(a.data), copy(a.axes))
    elseif expr isa ImplyExpr
        a = _eval((expr::ImplyExpr).a, ctx, inputs, cfg, consts, env, backend, planner)
        b = _eval((expr::ImplyExpr).b, ctx, inputs, cfg, consts, env, backend, planner)
        axes, Aa, Bb = _align_pair(a, b)
        return LabeledTensor(_imply_apply(cfg, Aa, Bb), axes)
    elseif expr isa ExistsExpr
        e = expr::ExistsExpr
        # domain binding (optional)
        if e.domain != :Any
            if _has(env, e.var.name)
                env[e.var.name] == e.domain || throw(ArgumentError("variable $(e.var.name) domain mismatch: $(env[e.var.name]) vs $(e.domain)"))
            else
                set!(env, e.var.name, e.domain)
            end
        end

        # optimization: if body is a pure product-conjunction of predicates and reduce kind is sum/mean,
        # route through contraction backend to avoid huge intermediates.
        opt = _eval_exists_conjunction(e, ctx, inputs, cfg, consts, env; backend=backend, planner=planner)
        if opt !== nothing
            return opt
        end

        body = _eval(e.body, ctx, inputs, cfg, consts, env, backend, planner)
        return _reduce_exists(cfg, body, e.var.name)
    elseif expr isa ForallExpr
        e = expr::ForallExpr
        inner = ExistsExpr(e.var, e.domain, NotExpr(e.body))
        ex = _eval(inner, ctx, inputs, cfg, consts, env, backend, planner)
        return LabeledTensor(_not_apply(ex.data), copy(ex.axes))
    else
        throw(ArgumentError("unknown TLExpr node"))
    end
end
