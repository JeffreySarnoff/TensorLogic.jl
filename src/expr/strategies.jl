#------------------------------------------------------------------------------
# Compilation strategies: connective semantics mapping
#------------------------------------------------------------------------------
"""Semantic configuration for interpreting connectives and quantifiers.

See `soft_differentiable()`, `fuzzy_godel()`, and `probabilistic()` constructors.
"""
struct CompilationConfig
    strategy::Symbol
end

soft_differentiable() = CompilationConfig(:soft_differentiable)
hard_boolean()        = CompilationConfig(:hard_boolean)
fuzzy_godel()         = CompilationConfig(:fuzzy_godel)
fuzzy_product()       = CompilationConfig(:fuzzy_product)
fuzzy_lukasiewicz()   = CompilationConfig(:fuzzy_lukasiewicz)
probabilistic()       = CompilationConfig(:probabilistic)

@inline _one(T) = one(T)

@inline function _exists_reduce_kind(cfg::CompilationConfig)
    s = cfg.strategy
    if s === :soft_differentiable
        return :sum
    elseif s === :probabilistic
        return :mean
    else
        return :max
    end
end

@inline function _and_kind(cfg::CompilationConfig)
    s = cfg.strategy
    if s === :soft_differentiable || s === :fuzzy_product
        return :prod
    elseif s === :fuzzy_lukasiewicz
        return :luk_and
    elseif s === :probabilistic
        return :prob_and
    else
        return :min
    end
end

@inline function _or_kind(cfg::CompilationConfig)
    s = cfg.strategy
    if s === :fuzzy_product || s === :probabilistic
        return :prob_or
    elseif s === :fuzzy_lukasiewicz
        return :luk_or
    else
        return :max
    end
end

@inline function _imply_kind(cfg::CompilationConfig)
    s = cfg.strategy
    if s === :soft_differentiable
        return :relu_diff
    elseif s === :fuzzy_godel
        return :godel
    else
        return :default_or_not
    end
end
