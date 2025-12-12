#------------------------------------------------------------------------------
# Dense execution backends
#
# Notes:
# - The sparse rule engine never uses these.
# - The expression language evaluator may route specific EXISTS+AND patterns
#   through a contraction backend for performance.
#------------------------------------------------------------------------------
using Dictionaries

abstract type DenseBackend end

"""Pure Julia fallback backend based on axis alignment + broadcast + reductions."""
struct BroadcastBackend <: DenseBackend end

broadcast_backend() = BroadcastBackend()

"""Construct an OMEinsum backend (available when OMEinsum.jl is loaded).

This function is extended by the TensorLogicOMEinsumExt extension.
Call with keyword arguments: `OMEinsumBackend(; optimize_order=true, ntrials=4, slice_target=nothing)`
"""
function OMEinsumBackend end

"""Resolve a backend selector into a concrete `DenseBackend`.

Selectors:
* `:auto`      -> choose the best available backend
* `:broadcast` -> broadcast backend
* `:omeinsum`  -> OMEinsum backend (requires optional extension)

You may also pass a concrete backend instance.
"""
function resolve_backend(backend)::DenseBackend
    backend isa DenseBackend && return backend

    if backend === :auto
        # Prefer OMEinsum when available; otherwise fall back to broadcast.
        # Check if the extension has added methods to OMEinsumBackend
        if !isempty(methods(OMEinsumBackend))
            return OMEinsumBackend()
        else
            return broadcast_backend()
        end
    elseif backend === :broadcast
        return broadcast_backend()
    elseif backend === :omeinsum
        if !isempty(methods(OMEinsumBackend))
            return OMEinsumBackend()
        end
        throw(ArgumentError("backend=:omeinsum requested but TensorLogicOMEinsumExt is not available. Add OMEinsum.jl to your environment."))
    end

    throw(ArgumentError("unknown backend selector: $backend"))
end

