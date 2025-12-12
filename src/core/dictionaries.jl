#------------------------------------------------------------------------------
# Dictionaries.jl helpers (avoid built-in dictionary type in src/)
#------------------------------------------------------------------------------
using Dictionaries

@inline _has(d::Dictionary, k) = isassigned(d, k)

@inline function _get(d::Dictionary, k, default)
    return _has(d, k) ? d[k] : default
end

@inline function _get_or_set!(d::Dictionary, k, default)
    if _has(d, k)
        return d[k]
    else
        set!(d, k, default)
        return default
    end
end

@inline _posmap(keys::Vector{Symbol}) = Dictionary(keys .=> collect(1:length(keys)))

@inline function _copy_dict(d::Dictionary{K,V}) where {K,V}
    d2 = Dictionary{K,V}()
    for (k,v) in pairs(d)
        set!(d2, k, v)
    end
    return d2
end
