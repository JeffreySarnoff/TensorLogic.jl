@testset "Sparse fixpoint engine (relations-as-tuples)" begin
    # ancestor via bracket equations
    src = """
    Parent[Alice, Bob].
    Parent[Bob, Charlie].
    Parent[Charlie, Dana].

    Ancestor[x,y] = Parent[x,y].
    Ancestor[x,z] = Ancestor[x,y] * Parent[y,z].
    """
    prog = parse_tensorlogic(src)
    ctx  = TLContext()
    run!(ctx, prog; maxiters=50)

    anc = Set(relation_tuples(ctx, :Ancestor))
    @test (:Alice, :Bob) in anc
    @test (:Alice, :Charlie) in anc
    @test (:Alice, :Dana) in anc
    @test (:Bob, :Dana) in anc

    # maxiters should stop (but still monotone)
    ctx2 = TLContext()
    run!(ctx2, prog; maxiters=1)
    anc2 = Set(relation_tuples(ctx2, :Ancestor))
    @test (:Alice, :Dana) ∉ anc2  # needs multiple iterations

    # arity mismatch errors
    prog_bad = parse_tensorlogic("P[A]. P[A,B].")
    ctx3 = TLContext()
    @test_throws ArgumentError run!(ctx3, prog_bad)

    # unbound head variable should error (invalid rule)
    prog_unbound = IRProgram(Atom[], [Rule(Atom(:H, [Var(:x)]), [Atom(:B, [Var(:y)])])])
    ctx4 = TLContext()
    run!(ctx4, IRProgram([Atom(:B,[Const(:A)])], Rule[]))
    @test_throws ArgumentError run!(ctx4, prog_unbound; maxiters=1)

    # constants in body should filter
    srcc = """
    P[A]. P[B].
    Q[A]. 
    R[x] = P[x] * Q[A].
    """
    prog = parse_tensorlogic(srcc)
    ctx5 = TLContext()
    run!(ctx5, prog)
    r = Set(relation_tuples(ctx5, :R))
    @test (:A,) in r
    @test (:B,) ∉ r

    # empty body rejected
    prog_empty = IRProgram(Atom[], [Rule(Atom(:H, [Const(:A)]), Atom[])])
    @test_throws ArgumentError run!(TLContext(), prog_empty)
end
