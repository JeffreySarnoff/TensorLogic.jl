#------------------------------------------------------------------------------
# Dense execution backends (optional)
#
# Design:
#   - The sparse rule engine never uses these.
#   - The expression language can optionally route "exists over product-conjunction
#     of predicates" through a contraction backend.
#------------------------------------------------------------------------------
abstract type DenseBackend end

"""Pure Julia fallback backend based on axis alignment + broadcast + reductions."""
struct BroadcastBackend <: DenseBackend end
broadcast_backend() = BroadcastBackend()

"""Resolve a backend selector into a concrete `DenseBackend`.

Backend selectors:
- `:auto`      -> choose the best available backend (currently `BroadcastBackend`)
- `:broadcast` -> `BroadcastBackend`
- `:omeinsum`  -> `OMEinsumBackend` if the OMEinsum extension is available

You can also pass an explicit `DenseBackend` instance.

"""
- :auto      -> choose best available (currently BroadcastBackend)
- :broadcast -> BroadcastBackend
- :omeinsum  -> OMEinsum backend if extension is loaded
"""
function resolve_backend(backend)::DenseBackend
    backend isa DenseBackend && return backend
    backend === :auto      && return BroadcastBackend()
    backend === :broadcast && return BroadcastBackend()
    if backend === :omeinsum
        # Provided by extension if OMEinsum is installed.
        if isdefined(TensorLogic, :OMEinsumBackend)
            return TensorLogic.OMEinsumBackend()  # default options; you can construct OMEinsumBackend(; ntrials=..., slice_target=...)
        end
        throw(ArgumentError("backend=:omeinsum requested but OMEinsum is not available. Add OMEinsum.jl to your environment."))
    end
    throw(ArgumentError("unknown backend: $backend"))
end
