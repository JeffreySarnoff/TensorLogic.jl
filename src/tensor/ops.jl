#------------------------------------------------------------------------------
# Dense operations using labeled tensors (optional helper)
#------------------------------------------------------------------------------
using Dictionaries

"""Multiply-join a list of labeled tensors and project onto `lhs_axes` by summing out others.

This is the dense analogue of a relational join (product) followed by projection (sum-out).

Requirements / behavior:
* `terms` must be non-empty
* axes with the same name must have the same extent across all terms
* the result is ordered exactly as `lhs_axes`
"""
function join_project_dense(terms::Vector{LabeledTensor}, lhs_axes::Vector{Symbol})
    isempty(terms) && throw(ArgumentError("join_project_dense: empty terms"))

    # Union axes and enforce size consistency across all terms.
    axes = Symbol[]
    sizes = Dictionary{Symbol,Int}()
    for t in terms
        for (i, ax) in enumerate(t.axes)
            ax in axes || push!(axes, ax)
            sz = size(t.data, i)
            if _has(sizes, ax)
                sizes[ax] == sz || throw(DimensionMismatch("axis $ax size mismatch: $(sizes[ax]) vs $sz"))
            else
                set!(sizes, ax, sz)
            end
        end
    end

    # Align all tensors to the union axis order, multiply pointwise.
    A = _align_to_axes(terms[1], axes)
    for k in 2:length(terms)
        B = _align_to_axes(terms[k], axes)
        A = A .* B
    end
    t = LabeledTensor(A, axes)

    # Sum out axes not in the requested lhs.
    for ax in reverse(axes)
        if !(ax in lhs_axes)
            t = sum_out_dense(t, ax)
        end
    end

    # Reorder to lhs_axes (and return).
    A2 = _align_to_axes(t, lhs_axes)
    return LabeledTensor(A2, copy(lhs_axes))
end
