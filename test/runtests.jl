using Test
using TensorLogic
using Dictionaries

@testset "TensorLogic.jl" begin
    @testset "Logic language + sparse engine" begin
        include("logic/test_rule_parser.jl")
        include("logic/test_sparse_engine.jl")
    end

    @testset "Expression language" begin
        include("expr/test_expr_parser.jl")
        include("expr/test_validate_and_exports.jl")
    end

    @testset "Tensor semantics + dense execution" begin
        include("tensor/test_dense_eval_semantics.jl")
    end
end
