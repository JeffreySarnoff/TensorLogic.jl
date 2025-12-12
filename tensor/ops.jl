#------------------------------------------------------------------------------
# Dense operations using labeled tensors (optional helper)
#------------------------------------------------------------------------------
using Dictionaries

"""Multiply-join a list of labeled tensors and project onto `lhs_axes` by summing out others.

This is a convenience helper for building the dense semantics:
1. Align all tensors to the union of their axes (in a stable order).
2. Multiply elementwise (product-style AND).
3. Sum out any axes not present in `lhs_axes`.
4. Reorder to `lhs_axes`.

Errors:
- throws `ArgumentError` if `terms` is empty or if `lhs_axes` contains an axis not present in any term
- throws `DimensionMismatch` if any shared axis has inconsistent sizes across terms
"""
function join_project_dense(terms::Vector{LabeledTensor}, lhs_axes::Vector{Symbol})
    isempty(terms) && throw(ArgumentError("join_project_dense: empty terms"))

    # union axes and size consistency across all terms
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

    for ax in lhs_axes
        ax in axes || throw(ArgumentError("join_project_dense: lhs axis $ax not present in any term"))
    end

    A = _align_to_axes(terms[1], axes)
    for k in 2:length(terms)
        B = _align_to_axes(terms[k], axes)
        A = A .* B
    end
    t = LabeledTensor(A, axes)

    # project away axes not in lhs_axes
    for ax in reverse(axes)
        if !(ax in lhs_axes)
            t = sum_out_dense(t, ax)
        end
    end

    # reorder to lhs_axes
    A2 = _align_to_axes(t, lhs_axes)
    return LabeledTensor(A2, copy(lhs_axes))
end
