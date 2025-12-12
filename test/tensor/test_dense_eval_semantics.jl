@testset "Dense evaluation: semantics + corner cases" begin
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

    # AND / OR / NOT / IMPLY
    @test eval_dense(parse_tlexpr("knows(x,y) & likes(x,y)"), ctx; inputs=inputs, config=soft_differentiable()).data ≈ knows .* likes
    @test eval_dense(parse_tlexpr("knows(x,y) | likes(x,y)"), ctx; inputs=inputs, config=soft_differentiable()).data ≈ max.(knows, likes)
    @test eval_dense(parse_tlexpr("!knows(x,y)"), ctx; inputs=inputs, config=soft_differentiable()).data ≈ (1 .- knows)
    @test eval_dense(parse_tlexpr("knows(x,y) -> likes(x,y)"), ctx; inputs=inputs, config=soft_differentiable()).data ≈ max.(0.0, likes .- knows)

    # quantifiers
    ex = eval_dense(parse_tlexpr("exists y:Person. knows(x,y)"), ctx; inputs=inputs, config=soft_differentiable(), backend=:broadcast)
    @test ex.axes == [:x]
    @test ex.data ≈ sum(knows, dims=2)[:]

    all = eval_dense(parse_tlexpr("forall y:Person. knows(x,y)"), ctx; inputs=inputs, config=soft_differentiable())
    @test all.data ≈ (1 .- sum(1 .- knows, dims=2)[:])

    # missing input tensor -> error
    inputs2 = Dictionary{Symbol,Any}()
    set!(inputs2, :knows, knows)
    @test_throws ArgumentError eval_dense(parse_tlexpr("knows(x,y) & likes(x,y)"), ctx; inputs=inputs2)

    # shape mismatch -> error
    bad = Dictionary{Symbol,Any}()
    set!(bad, :knows, rand(3,3))
    set!(bad, :likes, likes)
    @test_throws DimensionMismatch eval_dense(parse_tlexpr("knows(x,y)"), ctx; inputs=bad)

    # constants require consts mapping
    @test_throws ArgumentError eval_dense(parse_tlexpr("knows(Alice,y)"), ctx; inputs=inputs)
    consts = Dictionary{Symbol,Any}()
    set!(consts, :Person, Dictionary{Symbol,Int}(:Alice=>1, :Bob=>2))
    outc = eval_dense(parse_tlexpr("knows(Alice,y)"), ctx; inputs=inputs, consts=consts)
    @test outc.axes == [:y]
    @test outc.data ≈ knows[1, :]

    # special values: NaN / Inf should not crash; verify propagation patterns
    knows2 = copy(knows); knows2[1,1] = NaN
    likes2 = copy(likes); likes2[2,2] = Inf
    inputs3 = Dictionary{Symbol,Any}()
    set!(inputs3, :knows, knows2)
    set!(inputs3, :likes, likes2)

    out_or = eval_dense(parse_tlexpr("knows(x,y) | likes(x,y)"), ctx; inputs=inputs3, config=soft_differentiable()).data
    @test isnan(out_or[1,1])

    out_and = eval_dense(parse_tlexpr("knows(x,y) & likes(x,y)"), ctx; inputs=inputs3, config=soft_differentiable()).data
    @test isnan(out_and[1,1])

    out_not = eval_dense(parse_tlexpr("!knows(x,y)"), ctx; inputs=inputs3, config=soft_differentiable()).data
    @test isnan(out_not[1,1])

    out_ex = eval_dense(parse_tlexpr("exists y:Person. knows(x,y)"), ctx; inputs=inputs3, config=soft_differentiable()).data
    @test isnan(out_ex[1])

    # strategy spot-checks
    out_godel = eval_dense(parse_tlexpr("knows(x,y) -> likes(x,y)"), ctx; inputs=inputs, config=fuzzy_godel()).data
    expected_godel = ifelse.(knows .<= likes, 1.0, likes)
    @test out_godel ≈ expected_godel

    out_prob = eval_dense(parse_tlexpr("exists y:Person. knows(x,y)"), ctx; inputs=inputs, config=probabilistic()).data
    @test out_prob ≈ (sum(knows, dims=2)[:] ./ 2)
end
