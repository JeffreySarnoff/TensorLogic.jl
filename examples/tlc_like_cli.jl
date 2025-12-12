using TensorLogic

expr = parse_tlexpr("exists y:Person. knows(x,y) & likes(x,y)")
g = compile_graph(expr)

println("DOT:")
println(export_dot(g))

println("\nJSON:")
println(export_json(g))
