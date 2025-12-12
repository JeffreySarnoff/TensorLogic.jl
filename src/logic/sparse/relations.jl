#------------------------------------------------------------------------------
# Sparse relations-as-tuples backend
#------------------------------------------------------------------------------
using Dictionaries

"""A sparse relation of fixed arity `N`, stored as a set of `NTuple{N,Int}`."""
struct SparseRelation{N}
    tuples::Set{NTuple{N,Int}}
end
SparseRelation{N}() where {N} = SparseRelation{N}(Set{NTuple{N,Int}}())

Base.length(r::SparseRelation) = length(r.tuples)

@inline function _insert!(r::SparseRelation{N}, t::NTuple{N,Int}) where {N}
    before = length(r.tuples)
    push!(r.tuples, t)
    return length(r.tuples) != before
end
