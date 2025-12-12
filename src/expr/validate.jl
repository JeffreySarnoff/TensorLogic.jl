#------------------------------------------------------------------------------
# Validation report for tutorial-style expressions
#------------------------------------------------------------------------------
using Dictionaries

"""Validation report returned by `validate_expr`.

Fields:
- `ok` (Bool)
- `errors` (Vector{String})
- `warnings` (Vector{String})
"""
struct ValidationReport
    ok::Bool
    errors::Vector{String}
    warnings::Vector{String}
end

"""Validate an expression against declared domains and (optionally) predicate signatures."""
"""Validate a `TLExpr` against a `CompilerContext`.

Returns a `ValidationReport`.
"""
function validate_expr(expr::TLExpr, ctx::CompilerContext; strict::Bool=false)::ValidationReport
    errors = String[]
    warns  = String[]

    arity_seen = Dictionary{Symbol,Int}()
    bound = Symbol[]  # stack of bound vars

    warn(msg) = push!(warns, msg)
    err(msg)  = push!(errors, msg)

    function bind(v::Symbol, f)
        v in bound && warn("variable shadowing: $v is re-bound in nested quantifier")
        push!(bound, v)
        try
            return f()
        finally
            pop!(bound)
        end
    end

    function visit(e::TLExpr)
        if e isa Pred
            pe = e::Pred
            a = length(pe.args)
            if _has(arity_seen, pe.name)
                arity_seen[pe.name] == a || err("predicate $(pe.name) used with inconsistent arity: saw $(arity_seen[pe.name]) and $a")
            else
                set!(arity_seen, pe.name, a)
            end
            if _has(ctx.pred_domains, pe.name)
                length(ctx.pred_domains[pe.name]) == a || err("predicate $(pe.name) signature arity mismatch: declared $(length(ctx.pred_domains[pe.name])) vs used $a")
            else
                warn("predicate $(pe.name) has no declared signature; domain/dimension checks are limited")
            end
            for t in pe.args
                t isa ConstT && warn("constant $((t::ConstT).name) appears; dense evaluation requires a consts mapping")
            end
        elseif e isa AndExpr
            ee = e::AndExpr; visit(ee.a); visit(ee.b)
        elseif e isa OrExpr
            ee = e::OrExpr; visit(ee.a); visit(ee.b)
        elseif e isa NotExpr
            visit((e::NotExpr).x)
        elseif e isa ImplyExpr
            ee = e::ImplyExpr; visit(ee.a); visit(ee.b)
        elseif e isa ExistsExpr
            ee = e::ExistsExpr
            ee.domain != :Any && (!_has(ctx.domains, ee.domain) && err("domain $(ee.domain) not found (quantifier for $(ee.var.name)); add with add_domain!"))
            bind(ee.var.name) do
                visit(ee.body)
            end
        elseif e isa ForallExpr
            ee = e::ForallExpr
            ee.domain != :Any && (!_has(ctx.domains, ee.domain) && err("domain $(ee.domain) not found (quantifier for $(ee.var.name)); add with add_domain!"))
            bind(ee.var.name) do
                visit(ee.body)
            end
        else
            err("unknown TLExpr node encountered")
        end
    end

    visit(expr)

    if strict
        for p in keys(arity_seen)
            _has(ctx.pred_domains, p) || err("strict: predicate $(p) missing declared signature")
        end
    end

    ok = isempty(errors)
    return ValidationReport(ok, errors, warns)
end
