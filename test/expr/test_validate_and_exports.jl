@testset "Validation + graph exports (DOT/JSON)" begin
    expr = parse_tlexpr("exists y:Person. knows(x,y) & likes(x,y)")
    g = compile_graph(expr)
    st = graph_stats(g)
    @test st.nodes == length(g.nodes)
    @test st.op_counts[:pred] >= 2

    dot = export_dot(g)
    @test occursin("digraph", dot)
    @test occursin("exists", dot)

    js = export_json(g)
    @test occursin("\"nodes\"", js)
    @test occursin("\"edges\"", js)

    # validation: missing domain is an error
    ctx = CompilerContext()
    rep = validate_expr(expr, ctx)
    @test !rep.ok
    @test any(occursin("domain Person not found"), rep.errors)

    # once domain exists, ok (pred signatures optional => warnings)
    add_domain!(ctx, :Person, 2)
    rep2 = validate_expr(expr, ctx)
    @test rep2.ok
    @test length(rep2.warnings) >= 1

    # strict mode requires predicate signatures
    rep3 = validate_expr(expr, ctx; strict=true)
    @test !rep3.ok
    @test any(occursin("strict: predicate knows missing declared signature"), rep3.errors)

    # arity mismatch within expression
    expr_bad = parse_tlexpr("p(x) & p(x,y)")
    rep4 = validate_expr(expr_bad, ctx)
    @test !rep4.ok
    @test any(occursin("inconsistent arity", s) for s in rep4.errors)

    # shadowing warning
    expr_shadow = parse_tlexpr("exists x:Person. exists x:Person. knows(x,y)")
    rep5 = validate_expr(expr_shadow, ctx)
    @test any(occursin("shadowing", s) for s in rep5.warnings)
end
