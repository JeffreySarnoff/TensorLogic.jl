#------------------------------------------------------------------------------
# Compiler context for tutorial-style expressions (dense evaluation)
#------------------------------------------------------------------------------
using Dictionaries

"""Context for expression-language compilation and validation.

Stores domain sizes and predicate signatures.
"""
mutable struct CompilerContext
    domains::Dictionary{Symbol,Int}                 # domain => size
    pred_domains::Dictionary{Symbol,Vector{Symbol}} # pred => arg domains
end

CompilerContext() = CompilerContext(Dictionary{Symbol,Int}(), Dictionary{Symbol,Vector{Symbol}}())

"""Declare a domain of the given size."""
function add_domain!(ctx::CompilerContext, domain::Symbol, size::Integer)
    size > 0 || throw(ArgumentError("domain size must be positive, got $size"))
    set!(ctx.domains, domain, Int(size))
    return ctx
end

"""Declare a predicate signature: the domain for each argument."""
function declare_predicate!(ctx::CompilerContext, pred::Symbol, arg_domains::Vector{Symbol})
    set!(ctx.pred_domains, pred, arg_domains)
    return ctx
end

@inline function _domain_size(ctx::CompilerContext, dom::Symbol)
    _has(ctx.domains, dom) || throw(ArgumentError("domain $dom not declared; call add_domain!"))
    return ctx.domains[dom]
end

@inline function _pred_sig(ctx::CompilerContext, pred::Symbol)
    _has(ctx.pred_domains, pred) || throw(ArgumentError("predicate $pred signature not declared; call declare_predicate!"))
    return ctx.pred_domains[pred]
end
