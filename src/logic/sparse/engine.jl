#------------------------------------------------------------------------------
# Monotone forward-chaining engine for IRProgram (sparse tuple backend)
#------------------------------------------------------------------------------
using Dictionaries

"""Runtime context holding interned objects and predicate relations."""
mutable struct TLContext
    obj2id::Dictionary{Symbol,Int}
    id2obj::Vector{Symbol}
    rels::Dictionary{Symbol,Any}  # pred => SparseRelation{N}
end
TLContext() = TLContext(Dictionary{Symbol,Int}(), Symbol[], Dictionary{Symbol,Any}())

"""Intern a constant symbol and return its id."""
function intern!(ctx::TLContext, obj::Symbol)::Int
    if _has(ctx.obj2id, obj)
        return ctx.obj2id[obj]
    end
    id = length(ctx.id2obj) + 1
    push!(ctx.id2obj, obj)
    set!(ctx.obj2id, obj, id)
    return id
end

"""Inverse of `intern!`."""
object_symbol(ctx::TLContext, id::Int) = ctx.id2obj[id]

"""Ensure a relation exists for `pred` with arity `N` (error on mismatch)."""
function declare_relation!(ctx::TLContext, pred::Symbol, N::Int)
    if _has(ctx.rels, pred)
        r = ctx.rels[pred]
        ar = typeof(r).parameters[1]
        ar == N || throw(ArgumentError("predicate $pred already declared with arity $ar (requested $N)"))
        return r
    end
    r = SparseRelation{N}()
    set!(ctx.rels, pred, r)
    return r
end

@inline function _get_relation(ctx::TLContext, pred::Symbol, N::Int)
    return declare_relation!(ctx, pred, N)
end

function _encode_tuple!(ctx::TLContext, a::Atom)::Tuple{Symbol,Any}
    N = arity(a)
    rel = _get_relation(ctx, a.pred, N)
    tup = ntuple(i -> begin
        t = a.args[i]
        t isa Const || throw(ArgumentError("cannot encode non-ground atom as fact: $a"))
        intern!(ctx, (t::Const).name)
    end, N)
    return a.pred, (rel, tup)
end

function _add_fact!(ctx::TLContext, a::Atom)
    is_fact(a) || throw(ArgumentError("fact must be ground: $a"))
    pred, (rel, tup) = _encode_tuple!(ctx, a)
    return _insert!(rel, tup)
end

# -------- join/project for one rule (tuple engine)

@inline _isvar(t::Term) = t isa Var
@inline _varname(t::Term) = (t::Var).name

        end
    end
    return true
end

function _row_compatible!(ctx::TLContext, bind::Dictionary{Symbol,Int}, atom::Atom, row)::Bool
    for (i, t) in enumerate(atom.args)
        if t isa Var
            v = _varname(t)
            if _has(bind, v)
                bind[v] == row[i] || return false
            end
        else
            idc = intern!(ctx, (t::Const).name)
            row[i] == idc || return false
        end
    end
    return true
end

function _extend_bind!(ctx::TLContext, bind::Dictionary{Symbol,Int}, atom::Atom, row)::Nothing
    for (i, t) in enumerate(atom.args)
        if t isa Var
            v = _varname(t)
            if !_has(bind, v)
                set!(bind, v, row[i])
            end
        else
            # constant already checked
        end
    end
    return nothing
end

function _emit_head_tuple(ctx::TLContext, head::Atom, bind::Dictionary{Symbol,Int})
    N = arity(head)
    tup = ntuple(i -> begin
        t = head.args[i]
        if t isa Var
            v = _varname(t)
            _has(bind, v) || throw(ArgumentError("unbound head variable $v in rule"))
            bind[v]
        else
            intern!(ctx, (t::Const).name)
        end
    end, N)
    return tup
end

# Apply one rule: returns number of new tuples added
function _apply_rule!(ctx::TLContext, rule::Rule)::Int
    head = rule.head
    body = rule.body
    isempty(body) && throw(ArgumentError("rule body cannot be empty"))

    # ensure relations exist
    rels = Any[]
    for a in body
        push!(rels, _get_relation(ctx, a.pred, arity(a)))
    end
    headrel = _get_relation(ctx, head.pred, arity(head))

    # Heuristic optimization: join smaller relations first
    if length(body) > 1
        order = sortperm(1:length(body), by=i->length(rels[i]))
        body = [body[i] for i in order]
        rels = [rels[i] for i in order]
    end

    newcount = 0

    # DFS join over body relations
    function dfs(i::Int, bind::Dictionary{Symbol,Int})
        if i > length(body)
            tup = _emit_head_tuple(ctx, head, bind)
            _insert!(headrel, tup) && (newcount += 1)
            return
        end
        a = body[i]
        r = rels[i]
        for row in r.tuples
            if _row_compatible!(ctx, bind, a, row)
                # copy-on-write bind
                bind2 = bind
                # only allocate if new vars introduced
                needs_copy = false
                for t in a.args
                    if t isa Var
                        v = _varname(t)
                        if !_has(bind, v)
                            needs_copy = true; break
                        end
                    end
                end
                if needs_copy
                    bind2 = _copy_dict(bind)
                end
                _extend_bind!(ctx, bind2, a, row)
                dfs(i+1, bind2)
            end
        end
    end

    dfs(1, Dictionary{Symbol,Int}())
    return newcount
end

"""Run a rule program to a fixpoint (or `maxiters`). Returns `ctx`."""
function run!(ctx::TLContext, prog::IRProgram; maxiters::Int=50, stop::Symbol=:nochange)
    # facts
    for f in prog.facts
        _add_fact!(ctx, f)
    end

    # iterate rules
    for it in 1:maxiters
        delta = 0
        for r in prog.rules
            delta += _apply_rule!(ctx, r)
        end
        if stop === :nochange && delta == 0
            break
        end
    end
    return ctx
end

"""Return decoded tuples for a predicate, as tuples of `Symbol`."""
function relation_tuples(ctx::TLContext, pred::Symbol)
    _has(ctx.rels, pred) || return Tuple{Vararg{Symbol}}[]
    r = ctx.rels[pred]
    # return as tuples of Symbols; element type is intentionally generic for robustness across arities
    out = Tuple{Vararg{Symbol}}[]
    N = typeof(r).parameters[1]
    for t in r.tuples
        push!(out, ntuple(i -> object_symbol(ctx, t[i]), N))
    end
    return out
end
    return out
end
