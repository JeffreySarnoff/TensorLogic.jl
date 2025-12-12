using TensorLogic
using Dictionaries

expr = parse_tlexpr("forall x:Person. exists y:Person. knows(x,y) -> likes(x,y)")

ctx = CompilerContext()
add_domain!(ctx, :Person, 3)
declare_predicate!(ctx, :knows, [:Person,:Person])
declare_predicate!(ctx, :likes, [:Person,:Person])

rep = validate_expr(expr, ctx; strict=true)
println("ok = ", rep.ok)
println("warnings = ", rep.warnings)
println("errors = ", rep.errors)

g = compile_graph(expr)
println("\nDOT:")
println(export_dot(g))

println("\nJSON:")
println(export_json(g))
