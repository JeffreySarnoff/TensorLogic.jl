#------------------------------------------------------------------------------
# Monotone forward-chaining engine for IRProgram (sparse tuple backend)
#
# Semantics:
# - facts insert tuples into relations
# - each iteration applies all rules once, but **rule bodies see a snapshot**
#   of relations from the start of that iteration (so `maxiters` is meaningful)
# - iteration is monotone and stops at a fixpoint when no new tuples are added
#------------------------------------------------------------------------------
using Dictionaries

# --- context -----------------------------------------------------------------

"""Runtime context holding interned constants and predicate relations."""
mutable struct TLContext
    obj2id::Dictionary{Symbol,Int}     # constant symbol -> id
    id2obj::Vector{Symbol}            # id -> constant symbol
    rels::Dictionary{Symbol,Any}       # pred -> SparseRelation{N}
end

TLContext() = TLContext(Dictionary{Symbol,Int}(), Symbol[], Dictionary{Symbol,Any}())

"""Intern a constant symbol and return its integer id (stable within a context)."""
function intern!(ctx::TLContext, obj::Symbol)::Int
    if _has(ctx.obj2id, obj)
        return ctx.obj2id[obj]
    end
    id = length(ctx.id2obj) + 1
    push!(ctx.id2obj, obj)
    set!(ctx.obj2id, obj, id)
    return id
end

"""Inverse of `intern!` (id must be valid)."""
object_symbol(ctx::TLContext, id::Int) = ctx.id2obj[id]

# --- relations ---------------------------------------------------------------

@inline _arityof(::SparseRelation{N}) where {N} = N

"""Ensure a relation exists for `pred` with arity `N` (error on mismatch)."""
function declare_relation!(ctx::TLContext, pred::Symbol, N::Int)
    if _has(ctx.rels, pred)
        r = ctx.rels[pred]
        (r isa SparseRelation) || throw(ArgumentError("internal error: relation storage corrupted for $pred"))
        ar = _arityof(r)
        ar == N || throw(ArgumentError("predicate $pred already declared with arity $ar (requested $N)"))
        return r
    end
    r = SparseRelation{N}()
    set!(ctx.rels, pred, r)
    return r
end

@inline _get_relation(ctx::TLContext, pred::Symbol, N::Int) = declare_relation!(ctx, pred, N)

# --- facts -------------------------------------------------------------------

"""Encode a ground atom as an internal tuple of integer ids."""
function _encode_tuple!(ctx::TLContext, a::Atom)
    N = arity(a)
    rel = _get_relation(ctx, a.pred, N)
    tup = ntuple(i -> begin
        t = a.args[i]
        t isa Const || throw(ArgumentError("cannot encode non-ground atom as fact: $a"))
        intern!(ctx, (t::Const).name)
    end, N)
    return rel, tup
end

"""Insert a ground fact atom into the corresponding relation."""
function _add_fact!(ctx::TLContext, a::Atom)
    is_fact(a) || throw(ArgumentError("fact must be ground: $a"))
    rel, tup = _encode_tuple!(ctx, a)
    return _insert!(rel, tup)
end

# --- join/project ------------------------------------------------------------

@inline _varname(t::Term) = (t::Var).name

"""Check whether `row` from `atom.pred` is compatible with current bindings (and atom constants)."""
function _row_compatible!(ctx::TLContext, bind::Dictionary{Symbol,Int}, atom::Atom, row)::Bool
    @inbounds for (i, t) in enumerate(atom.args)
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

"""Extend bindings with any newly-seen variables from this atom/row match."""
function _extend_bind!(bind::Dictionary{Symbol,Int}, atom::Atom, row)::Nothing
    @inbounds for (i, t) in enumerate(atom.args)
        if t isa Var
            v = _varname(t)
            _has(bind, v) || set!(bind, v, row[i])
        end
    end
    return nothing
end

"""Emit a head tuple from bindings; head must contain only variables."""
function _emit_head_tuple(head::Atom, bind::Dictionary{Symbol,Int})
    N = arity(head)
    return ntuple(i -> begin
        t = head.args[i]
        t isa Var || throw(ArgumentError("rule head must be variables-only in this engine: $head"))
        v = _varname(t)
        _has(bind, v) || throw(ArgumentError("unbound head variable $v in rule: $head"))
        bind[v]
    end, N)
end

# --- rule application --------------------------------------------------------

"""Apply one rule once against a snapshot of relations; return number of new tuples added."""
function _apply_rule!(ctx::TLContext, rule::Rule, snap::Dictionary{Symbol,Any})::Int
    head = rule.head
    body = rule.body
    isempty(body) && throw(ArgumentError("rule body cannot be empty"))

    # Ensure relations exist (for arity checks) and grab snapshot rows.
    rows = Any[]
    sizes = Int[]
    for a in body
        _get_relation(ctx, a.pred, arity(a)) # declares empty if missing
        rs = _has(snap, a.pred) ? snap[a.pred] : NTuple{arity(a),Int}[]
        push!(rows, rs)
        push!(sizes, length(rs))
    end

    # Join order: smallest relation first (by snapshot size).
    if length(body) > 1
        ord = sortperm(1:length(body), by=i->sizes[i])
        body = [body[i] for i in ord]
        rows = [rows[i] for i in ord]
    end

    headrel = _get_relation(ctx, head.pred, arity(head))
    newcount = 0

    function dfs(i::Int, bind::Dictionary{Symbol,Int})
        if i > length(body)
            tup = _emit_head_tuple(head, bind)
            _insert!(headrel, tup) && (newcount += 1)
            return
        end

        a = body[i]
        rs = rows[i]
        for row in rs
            _row_compatible!(ctx, bind, a, row) || continue

            # Avoid copying unless this atom introduces new vars.
            needs_copy = false
            for t in a.args
                if t isa Var
                    v = _varname(t)
                    if !_has(bind, v)
                        needs_copy = true
                        break
                    end
                end
            end

            bind2 = needs_copy ? copy(bind) : bind
            needs_copy && _extend_bind!(bind2, a, row)
            dfs(i + 1, bind2)
        end
    end

    dfs(1, Dictionary{Symbol,Int}())
    return newcount
end

# --- program execution -------------------------------------------------------

"""Run a program in a context. Returns `ctx` after running.

Keyword arguments:
- `maxiters`: maximum rule-application iterations
- `stop`: `:fixpoint` (default) or `:maxiters`
"""
function run!(ctx::TLContext, prog::IRProgram; maxiters::Int=50, stop::Symbol=:fixpoint)
    # Insert facts.
    for a in prog.facts
        _add_fact!(ctx, a)
    end

    # Iterate rules to a fixpoint (rule bodies see a per-iteration snapshot).
    for _ in 1:maxiters
        snap = Dictionary{Symbol,Any}()
        for (pred, rel) in pairs(ctx.rels)
            set!(snap, pred, collect((rel::SparseRelation).tuples))
        end

        added = 0
        for r in prog.rules
            added += _apply_rule!(ctx, r, snap)
        end
        (stop === :fixpoint && added == 0) && break
    end
    return ctx
end

# --- user-facing helpers -----------------------------------------------------

"""Return decoded tuples for a predicate as `NTuple{N,Symbol}` values.

If the predicate is unknown, returns an empty vector.
"""
function relation_tuples(ctx::TLContext, pred::Symbol)
    _has(ctx.rels, pred) || return Tuple{Vararg{Symbol}}[]
    r = ctx.rels[pred]
    (r isa SparseRelation) || throw(ArgumentError("internal error: relation storage corrupted for $pred"))
    N = _arityof(r)
    out = Vector{NTuple{N,Symbol}}()
    for t in r.tuples
        push!(out, ntuple(i -> object_symbol(ctx, t[i]), N))
    end
    return out
end
