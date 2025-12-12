#------------------------------------------------------------------------------
# Dense labeled tensors (optional helper)
#------------------------------------------------------------------------------
using Dictionaries
using LinearAlgebra

"""Dense tensor paired with axis symbols (one per dimension)."""
struct LabeledTensor{A<:AbstractArray}
    data::A
    axes::Vector{Symbol}

    function LabeledTensor{A}(data::A, axes::Vector{Symbol}) where {A<:AbstractArray}
        ndims(data) == length(axes) || throw(ArgumentError("number of axes must match number of dimensions"))
        new{A}(data, axes)
    end

    function LabeledTensor(data::A, axes::Vector{Symbol}) where {A<:AbstractArray}
        ndims(data) == length(axes) || throw(ArgumentError("number of axes must match number of dimensions"))
        new{A}(data, axes)
    end
end

"""Return a map axis=>size."""
function axis_sizes(t::LabeledTensor)
    d = Dictionary{Symbol,Int}()
    for (i, ax) in enumerate(t.axes)
        set!(d, ax, size(t.data, i))
    end
    return d
end

"""Check that shared axes have identical sizes."""
function check_compatible!(a::LabeledTensor, b::LabeledTensor)
    da = axis_sizes(a); db = axis_sizes(b)
    for ax in keys(da)
        if _has(db, ax)
            da[ax] == db[ax] || throw(DimensionMismatch("axis $ax size mismatch: $(da[ax]) vs $(db[ax])"))
        end
    end
    return nothing
end

# Permute tensor so that its axes order equals `newaxes` (subset allowed if axis missing).
function permute_to(t::LabeledTensor, newaxes::Vector{Symbol})
    length(newaxes) == length(t.axes) || throw(ArgumentError("permute_to requires a full permutation of axes"))
    perm = Int[]
    for ax in newaxes
        p = findfirst(==(ax), t.axes)
        p === nothing && throw(ArgumentError("permute_to: axis $ax not present"))
        push!(perm, p)
    end
    if all(perm[i] == i for i in 1:length(perm))
        return t.data
    end
    return permutedims(t.data, perm)
end

# Align to union axes: reorder and reshape with singleton dims for missing axes.
function _align_to_axes(t::LabeledTensor, axes::Vector{Symbol})
    # compute order for existing axes within `axes`
    existing = Symbol[]
    for ax in axes
        ax in t.axes && push!(existing, ax)
    end
    A = permute_to(t, existing)
    # reshape by inserting singleton dims for missing axes
    shp = Int[]
    j = 1
    for ax in axes
        if ax in t.axes
            push!(shp, size(A, j))
            j += 1
        else
            push!(shp, 1)
        end
    end
    return reshape(A, shp...)
end

# Sum out one axis from labeled tensor
function sum_out_dense(t::LabeledTensor, ax::Symbol)
    p = findfirst(==(ax), t.axes)
    p === nothing && return t
    data = sum(t.data, dims=p)
    data2 = dropdims(data, dims=p)
    axes2 = [a for a in t.axes if a != ax]
    return LabeledTensor(data2, axes2)
end
