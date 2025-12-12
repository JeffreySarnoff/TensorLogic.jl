@testset "Expression parser" begin
    e = parse_tlexpr("knows(x,y) & likes(x,y)")
    @test e isa TensorLogic.AndExpr

    e2 = parse_tlexpr("!(knows(x,y) | likes(x,y))")
    @test e2 isa TensorLogic.NotExpr

    # right associative implication
    e3 = parse_tlexpr("a(x) -> b(x) -> c(x)")
    @test e3 isa TensorLogic.ImplyExpr
    @test (e3::TensorLogic.ImplyExpr).b isa ImplyExpr

    # quantifiers with/without domain
    e4 = parse_tlexpr("exists y:Person. knows(x,y)")
    @test e4 isa TensorLogic.ExistsExpr
    @test (e4::TensorLogic.ExistsExpr).domain == :Person

    e5 = parse_tlexpr("forall x. p(x)")
    @test e5 isa TensorLogic.ForallExpr
    @test (e5::TensorLogic.ForallExpr).domain == :Any

    # parse errors
    @test_throws ArgumentError parse_tlexpr("knows(x,y") # missing ')'
    @test_throws ArgumentError parse_tlexpr("exists . p(x)") # missing var
    @test_throws ArgumentError parse_tlexpr("-> p(x)") # invalid start
end
