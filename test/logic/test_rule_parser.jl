@testset "Rule parser" begin
    # facts: bracket and paren
    prog = parse_tensorlogic("P[A,B]. Q(A,B).")
    @test length(prog.facts) == 2
    @test length(prog.rules) == 0

    # datalog rule with commas
    prog = parse_tensorlogic("R(x) :- P(x), Q(x).")
    @test length(prog.rules) == 1
    @test prog.rules[1].head.pred == :R
    @test length(prog.rules[1].body) == 2

    # equation rule with multiplication
    prog = parse_tensorlogic("S[x,z] = R[x,y] * Q[y,z].")
    @test length(prog.rules) == 1
    @test prog.rules[1].head.pred == :S
    @test length(prog.rules[1].body) == 2

    # semicolons and comments
    src = """
    # comment
    Parent[Alice,Bob]; % comment
    Ancestor[x,y] = Parent[x,y]; # comment
    """
    prog = parse_tensorlogic(src)
    @test length(prog.facts) == 1
    @test length(prog.rules) == 1

    # string constant support
    prog = parse_tensorlogic("Name[\"Alice\", Bob].")
    @test prog.facts[1].args[1] isa Const

    # parse errors are local
    @test_throws ArgumentError parse_tensorlogic("P[.]")
    @test_throws ArgumentError parse_tensorlogic("P(A,B")  # missing ')'
    @test_throws ArgumentError parse_tensorlogic(":- P(x).") # invalid start
end
