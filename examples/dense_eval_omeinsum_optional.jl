using TensorLogic
using Dictionaries

# This example requires: using OMEinsum
try
    @eval using OMEinsum
catch
    println("OMEinsum not installed. Run: ] add OMEinsum")
    exit(0)
end

ctx = CompilerContext()
add_domain!(ctx, :Person, 3)
declare_predicate!(ctx, :p, [:Person,:Person])
declare_predicate!(ctx, :q, [:Person,:Person])
declare_predicate!(ctx, :r, [:Person,:Person])

inputs = Dictionary{Symbol,Any}()
set!(inputs, :p, rand(3,3))
set!(inputs, :q, rand(3,3))
set!(inputs, :r, rand(3,3))

expr = parse_tlexpr("exists y:Person. p(x,y) & q(y,z) & r(z,y)")

# Broadcast backend
out1 = eval_dense(expr, ctx; inputs=inputs, config=soft_differentiable(), backend=:broadcast)

# OMEinsum backend (with order optimization if OMEinsumContractionOrders is installed)
be = TensorLogic.OMEinsumBackend(; ntrials=8, slice_target=nothing)
out2 = eval_dense(expr, ctx; inputs=inputs, config=soft_differentiable(), backend=be)

println("broadcast result size: ", size(out1.data), " axes=", out1.axes)
println("omeinsum  result size: ", size(out2.data), " axes=", out2.axes)
println("max abs diff: ", maximum(abs.(out1.data .- out2.data)))
