#------------------------------------------------------------------------------
# Simple contraction planner (greedy) for product-conjunctions with exists-sum/mean
#------------------------------------------------------------------------------
using Dictionaries

abstract type ContractionPlanner end
"""A simple greedy planner that chooses pairwise contractions to keep intermediates small."""
struct GreedyPlanner <: ContractionPlanner end
greedy_planner() = GreedyPlanner()

"""A pairwise contraction plan for factors (indices into the current list)."""
struct ContractionPlan
    pairs::Vector{Tuple{Int,Int}}
end

# Estimate size of a labeled tensor by product of axis lengths.
function _est_size(axes::Vector{Symbol}, axislen::Function)::Int
    s = 1
    for ax in axes
        s *= axislen(ax)
    end
    return s
end

"""Greedy plan: repeatedly contract the pair with smallest estimated intermediate size."""
function plan_contraction(::GreedyPlanner, factor_axes::Vector{Vector{Symbol}}, axislen::Function)
    # Represent each factor by its axis set (vector), mutable during planning.
    axes = [copy(a) for a in factor_axes]
    alive = collect(1:length(axes))
    pairs = Tuple{Int,Int}[]

    while length(alive) > 1
        best = nothing
        best_cost = typemax(Int)

        for ii in 1:length(alive)-1, jj in ii+1:length(alive)
            i = alive[ii]; j = alive[jj]
            # intermediate axes = union
            u = copy(axes[i])
            for ax in axes[j]
                ax in u || push!(u, ax)
            end
            cost = _est_size(u, axislen)
            if cost < best_cost
                best_cost = cost
                best = (ii, jj)
            end
        end

        best === nothing && error("planner internal error")
        ii, jj = best
        i = alive[ii]; j = alive[jj]
        push!(pairs, (i, j))

        # merge j into i
        u = axes[i]
        for ax in axes[j]
            ax in u || push!(u, ax)
        end
        axes[i] = u

        # remove j from alive
        deleteat!(alive, jj)
    end

    return ContractionPlan(pairs)
end
