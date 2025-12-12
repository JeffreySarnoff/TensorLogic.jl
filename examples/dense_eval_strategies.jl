using TensorLogic
using Dictionaries

ctx = CompilerContext()
add_domain!(ctx, :Person, 2)
declare_predicate!(ctx, :knows, [:Person,:Person])
declare_predicate!(ctx, :likes, [:Person,:Person])

knows = Float64[0.0 0.2;
                0.9 1.0]
likes = Float64[0.1 0.1;
                0.3 0.8]

inputs = Dictionary{Symbol,Any}()
set!(inputs, :knows, knows)
set!(inputs, :likes, likes)

expr = parse_tlexpr("exists y:Person. knows(x,y) & likes(x,y)")

println("soft_differentiable:")
println(eval_dense(expr, ctx; inputs=inputs, config=soft_differentiable()).data)

println("fuzzy_godel:")
println(eval_dense(expr, ctx; inputs=inputs, config=fuzzy_godel()).data)

println("probabilistic:")
println(eval_dense(expr, ctx; inputs=inputs, config=probabilistic()).data)
