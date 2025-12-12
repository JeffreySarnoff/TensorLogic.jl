#------------------------------------------------------------------------------
# Dense operations using labeled tensors (optional helper)
#------------------------------------------------------------------------------

"""Multiply-join a list of labeled tensors and project onto `lhs_axes` by summing out others."""
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

    A = _align_to_axes(terms[1], axes)
    for k in 2:length(terms)
        B = _align_to_axes(terms[k], axes)
        A = A .* B
    end
    t = LabeledTensor(A, axes)

    for ax in reverse(axes)
        if !(ax in lhs_axes)
            t = sum_out_dense(t, ax)
        end
    end

    A2 = _align_to_axes(t, lhs_axes)
    return LabeledTensor(A2, copy(lhs_axes))
end
    end
    # align
    A = _align_to_axes(terms[1], axes)
    for k in 2:length(terms)
        check_compatible!(terms[1], terms[k]) # shared axes sizes
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
    # remove singleton dims (shouldn't exist for lhs axes)
    return LabeledTensor(A2, copy(lhs_axes))
end
