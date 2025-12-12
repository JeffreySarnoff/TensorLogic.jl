#------------------------------------------------------------------------------
# Contraction helpers for dense expression evaluation
#------------------------------------------------------------------------------
using Dictionaries

"""Flatten a product-conjunction into a list of factor expressions.
Returns `nothing` if the expression contains anything other than `Pred` and `AndExpr` nodes.
"""
function _collect_prod_factors(expr::TLExpr)
    factors = TLExpr[]
    function go(e::TLExpr)
        if e isa AndExpr
            ee = e::AndExpr
            go(ee.a); go(ee.b)
        elseif e isa Pred
            push!(factors, e)
        else
            return false
        end
        return true
    end
    ok = go(expr)
    return ok ? factors : nothing
end

# Multiply two labeled tensors into union axes.
function _mul_union(a::LabeledTensor, b::LabeledTensor)
    axes = copy(a.axes)
    for ax in b.axes
        ax in axes || push!(axes, ax)
    end
    Aa = _align_to_axes(a, axes)
    Bb = _align_to_axes(b, axes)
    return LabeledTensor(Aa .* Bb, axes)
end

# Reduce one axis with sum/mean/max per `reduce_kind`
function _reduce_axis(t::LabeledTensor, ax::Symbol, reduce_kind::Symbol)
    if reduce_kind === :sum
        return sum_out_dense(t, ax)
    elseif reduce_kind === :mean
        p = findfirst(==(ax), t.axes)
        p === nothing && return t
        k = size(t.data, p)
        s = sum_out_dense(t, ax)
        return LabeledTensor(s.data ./ k, s.axes)
    elseif reduce_kind === :max
        p = findfirst(==(ax), t.axes)
        p === nothing && return t
        data = maximum(t.data, dims=p)
        data2 = dropdims(data, dims=p)
        axes2 = [a for a in t.axes if a != ax]
        return LabeledTensor(data2, axes2)
    else
        throw(ArgumentError("unknown reduce_kind: $reduce_kind"))
    end
end

"""Contract a list of factor tensors with a pairwise plan under BroadcastBackend."""
function _contract_broadcast(factors::Vector{LabeledTensor}, plan::ContractionPlan)
    # We'll keep a dictionary index->tensor, because plan indices reference original ids.
    tens = Dictionary{Int,LabeledTensor}()
    for (i, t) in enumerate(factors)
        set!(tens, i, t)
    end
    alive = Set(collect(1:length(factors)))

    for (i, j) in plan.pairs
        # If i or j already merged away, skip (planner uses original indices; our alive set handles this)
        if !(i in alive) || !(j in alive)
            continue
        end
        tij = _mul_union(tens[i], tens[j])
        set!(tens, i, tij)
        delete!(alive, j)
    end

    # The last alive id holds result
    last_id = first(alive)
    return tens[last_id]
end

"""Try to evaluate `exists v. body` by factoring body into predicates and contracting with a planner.

This optimization is enabled only when:
- AND-kind is `:prod` (product semantics),
- exists-reduce kind is `:sum` or `:mean`,
- body is a pure conjunction of predicates.

Otherwise, callers should fall back to generic evaluation.
"""
function _eval_exists_conjunction(
    e::ExistsExpr,
    ctx::CompilerContext,
    inputs::Dictionary{Symbol,Any},
    cfg::CompilationConfig,
    consts,
    env::Dictionary{Symbol,Symbol};
    backend::DenseBackend,
    planner::ContractionPlanner,
)
    # Must be product semantics; and must be sum/mean to map to einsum-style contractions.
    _and_kind(cfg) === :prod || return nothing
    rk = _exists_reduce_kind(cfg)
    (rk === :sum || rk === :mean) || return nothing

    factors_expr = _collect_prod_factors(e.body)
    factors_expr === nothing && return nothing

    # Evaluate each factor to a labeled tensor (this will also populate env with domains)
    factors = LabeledTensor[]
    for fe in factors_expr
        push!(factors, _pred_tensor(fe::Pred, ctx, inputs, consts, env))
    end

    # If the quantified variable does not appear, generic reduction would be no-op; keep it consistent
    v = e.var.name
    appears = any(v in t.axes for t in factors)
    appears || return _eval(e.body, ctx, inputs, cfg, consts, env, backend, planner)

    # Separate factors containing v from those that don't.
    fv = LabeledTensor[]
    fnv = LabeledTensor[]
    for t in factors
        (v in t.axes) ? push!(fv, t) : push!(fnv, t)
    end

    # Planner needs axis lengths; derive from env -> domain sizes.
    axislen = ax -> begin
        _has(env, ax) || throw(ArgumentError("internal error: missing domain for variable $ax"))
        dom = env[ax]
        _domain_size(ctx, dom)
    end

    # Contract v-containing factors with plan
    if length(fv) == 0
        # should not happen because appears==true
        core = LabeledTensor(fill(one(Float64)), Symbol[])
    elseif length(fv) == 1
        core = fv[1]
    else
        faxes = [t.axes for t in fv]
        plan = plan_contraction(planner, faxes, axislen)
        if backend isa BroadcastBackend
            core = _contract_broadcast(fv, plan)
        else
            # non-broadcast backends provide _contract_backend (extension can add methods)
            core = _contract_backend(backend, fv, plan)
        end
    end

    # Reduce out v
    core2 = _reduce_axis(core, v, rk)

    # Multiply back the v-free factors
    out = core2
    for t in fnv
        out = _mul_union(out, t)
    end

    return out
end

# Default hook; extension can add method for OMEinsumBackend
function _contract_backend(::DenseBackend, factors::Vector{LabeledTensor}, plan::ContractionPlan)
    throw(ArgumentError("backend does not implement contraction"))
end
