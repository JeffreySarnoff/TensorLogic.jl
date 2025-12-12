#------------------------------------------------------------------------------
# IR for rule programs (facts + rules)
#------------------------------------------------------------------------------

"""A term in the rule IR: either `Var` or `Const`."""
abstract type Term end

"""Logic variable term."""
struct Var <: Term
    name::Symbol
end

"""Constant term."""
struct Const <: Term
    name::Symbol
end

"""Predicate applied to arguments."""
struct Atom
    pred::Symbol
    args::Vector{Term}
end

"""A rule `head :- body...` (or equivalent bracket rule)."""
struct Rule
    head::Atom
    body::Vector{Atom}
end

"""A program consisting of a list of ground facts and rules."""
struct IRProgram
    facts::Vector{Atom}
    rules::Vector{Rule}
end

"""Number of arguments in an atom."""
arity(a::Atom) = length(a.args)

"""True iff the atom contains no variables."""
function is_fact(a::Atom)
    for t in a.args
        t isa Var && return false
    end
    return true
end
