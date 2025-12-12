module TensorLogicOMEinsumExt

using TensorLogic
using OMEinsum

"""Dense backend powered by OMEinsum for sum/mean EXISTS-contractions.

Options:
- `optimize_order`: try to use OMEinsumContractionOrders when installed.
- `ntrials`: TreeSA trials (small value keeps overhead low).
- `slice_target`: if set, attempt to slice the optimized code to reduce memory (higher = more slicing).
"""
struct OMEinsumBackend <: TensorLogic.DenseBackend
    optimize_order::Bool
    ntrials::Int
    slice_target::Union{Nothing,Int}
end

TensorLogic.OMEinsumBackend() = OMEinsumBackend(true, 4, nothing)
TensorLogic.OMEinsumBackend(; optimize_order::Bool=true, ntrials::Int=4, slice_target::Union{Nothing,Int}=nothing) =
    OMEinsumBackend(optimize_order, ntrials, slice_target)

const _LABELS = [collect('a':'z'); collect('A':'Z')]

function _axismap(axessets)
    axes = Symbol[]
    for a in axessets
        for ax in a
            ax in axes || push!(axes, ax)
        end
    end
    length(axes) <= length(_LABELS) || throw(ArgumentError("too many axes for OMEinsum backend: $(length(axes))"))
    m = TensorLogic.Dictionary{Symbol,Char}()
    for (i, ax) in enumerate(axes)
        TensorLogic.set!(m, ax, _LABELS[i])
    end
    return m
end

_labels(m, axes::Vector{Symbol}) = String([m[ax] for ax in axes])

# A tiny AbstractDict adapter so we can pass sizes without using built-in Dict as our storage.
struct IntSizeMap <: AbstractDict{Int,Int}
    d::TensorLogic.Dictionary{Int,Int}
end
Base.length(m::IntSizeMap) = length(m.d)
Base.haskey(m::IntSizeMap, k::Int) = TensorLogic._has(m.d, k)
Base.getindex(m::IntSizeMap, k::Int) = m.d[k]
Base.iterate(m::IntSizeMap, st...) = iterate(pairs(m.d), st...)
Base.keys(m::IntSizeMap) = (p.first for p in pairs(m.d))
Base.pairs(m::IntSizeMap) = pairs(m.d)

# One-time optional load of OMEinsumContractionOrders
const _OCO_STATUS = Base.RefValue{Int}(0) # 0 unknown, 1 available, -1 missing
function _ensure_oco()
    st = _OCO_STATUS[]
    if st == 1
        return true
    elseif st == -1
        return false
    end
    try
        @eval begin
            using OMEinsumContractionOrders
            using OMEinsumContractionOrders: EinCode, optimize_code, TreeSA, contraction_complexity
            using OMEinsumContractionOrders: slice_code, TreeSASlicer, ScoreFunction
        end
        _OCO_STATUS[] = 1
        return true
    catch
        _OCO_STATUS[] = -1
        return false
    end
end

# Cache optimized codes by a stable hash of (inputs, output, sizes, ntrials, slice_target).
const _CODE_CACHE = TensorLogic.Dictionary{UInt64,Any}()
const _CACHE_LOCK = Base.ReentrantLock()

function _hash_key(inputs_int::Vector{Vector{Int}}, output_int::Vector{Int},
                   sizes::TensorLogic.Dictionary{Int,Int}, ntrials::Int, slice_target)
    # determinize sizes iteration by sorting keys
    ks = sort(collect(keys(sizes)))
    sz = Tuple((k, sizes[k]) for k in ks)
    return hash((inputs_int, output_int, sz, ntrials, slice_target)) % UInt64
end

function _maybe_optimize_and_slice_code(inputs_int::Vector{Vector{Int}}, output_int::Vector{Int},
                                       sizes::TensorLogic.Dictionary{Int,Int},
                                       ntrials::Int, slice_target::Union{Nothing,Int})
    _ensure_oco() || return nothing
    size_map = IntSizeMap(sizes)
    code = OMEinsumContractionOrders.EinCode(inputs_int, output_int)
    opt = OMEinsumContractionOrders.optimize_code(code, size_map, OMEinsumContractionOrders.TreeSA(ntrials=ntrials))
    if slice_target !== nothing
        slicer = OMEinsumContractionOrders.TreeSASlicer(score=OMEinsumContractionOrders.ScoreFunction(sc_target=slice_target))
        try
            opt = OMEinsumContractionOrders.slice_code(opt, size_map, slicer)
        catch
            # If slicing fails for some reason, proceed with optimized code.
        end
    end
    return opt
end

"""Contract factors for EXISTS by directly summing out `v` using einsum.

Output axes = union(axes(factors)) \ {v}.
- For `:sum` reduction: compute einsum with v omitted from output.
- For `:mean` reduction: compute sum then divide by size(v).

Best practice (per OMEinsum docs):
- For >2 inputs, try to optimize contraction order using OMEinsumContractionOrders when installed.
- Optionally slice the code if memory is a concern.
"""
function TensorLogic._exists_contract_backend(be::OMEinsumBackend, factors::Vector{TensorLogic.LabeledTensor},
                                            v::Symbol, reduce_kind::Symbol,
                                            axislen::Function, planner)
    # Build axis map and output axes
    m = _axismap([t.axes for t in factors])
    out_axes = Symbol[]
    for t in factors
        for ax in t.axes
            ax == v && continue
            ax in out_axes || push!(out_axes, ax)
        end
    end

    # Build string code for direct einsum contraction
    in_specs = String[]
    arrays = Any[]
    for t in factors
        push!(in_specs, _labels(m, t.axes))
        push!(arrays, t.data)
    end
    out_spec = _labels(m, out_axes)
    code_str = join(in_specs, ",") * "->" * out_spec

    # Build integer-label representation for order optimization
    axes_all = Symbol[]
    for t in factors
        for ax in t.axes
            ax in axes_all || push!(axes_all, ax)
        end
    end
    idx = TensorLogic.Dictionary{Symbol,Int}()
    for (i, ax) in enumerate(axes_all)
        TensorLogic.set!(idx, ax, i)
    end
    inputs_int = [ [Int(idx[ax]) for ax in t.axes] for t in factors ]
    output_int = [ Int(idx[ax]) for ax in out_axes ]
    sizes = TensorLogic.Dictionary{Int,Int}()
    for ax in axes_all
        TensorLogic.set!(sizes, Int(idx[ax]), axislen(ax))
    end

    # Cache optimized code when enabled and meaningful.
    optcode = nothing
    if be.optimize_order && length(factors) > 2
        key = _hash_key(inputs_int, output_int, sizes, be.ntrials, be.slice_target)
        lock(_CACHE_LOCK) do
            if TensorLogic._has(_CODE_CACHE, key)
                optcode = _CODE_CACHE[key]
            else
                optcode = _maybe_optimize_and_slice_code(inputs_int, output_int, sizes, be.ntrials, be.slice_target)
                TensorLogic.set!(_CODE_CACHE, key, optcode)  # may be nothing; cache that too
            end
        end
    end

    data = if optcode === nothing
        OMEinsum.einsum(code_str, arrays...)
    else
        OMEinsum.einsum(optcode, arrays...)
    end

    if reduce_kind === :mean
        data = data ./ axislen(v)
    end
    return TensorLogic.LabeledTensor(data, out_axes)
end

# Pairwise contraction fallback (kept for completeness)
function TensorLogic._contract_backend(::OMEinsumBackend, factors::Vector{TensorLogic.LabeledTensor}, plan::TensorLogic.ContractionPlan)
    m = _axismap([t.axes for t in factors])
    tens = TensorLogic.Dictionary{Int,TensorLogic.LabeledTensor}()
    for (i, t) in enumerate(factors)
        TensorLogic.set!(tens, i, t)
    end
    alive = Set(collect(1:length(factors)))

    for (i, j) in plan.pairs
        if !(i in alive) || !(j in alive); continue; end
        a = tens[i]; b = tens[j]
        out_axes = copy(a.axes)
        for ax in b.axes
            ax in out_axes || push!(out_axes, ax)
        end
        la = _labels(m, a.axes); lb = _labels(m, b.axes); lo = _labels(m, out_axes)
        code = la * "," * lb * "->" * lo
        data = OMEinsum.einsum(code, a.data, b.data)
        TensorLogic.set!(tens, i, TensorLogic.LabeledTensor(data, out_axes))
        delete!(alive, j)
    end
    return tens[first(alive)]
end

end # module
