module TensorLogic

using Dictionaries
using JSON3
using LinearAlgebra

#------------------------------------------------------------------------------
# Utility + contracts
#------------------------------------------------------------------------------
include("core/dictionaries.jl")

#------------------------------------------------------------------------------
# Rule-program path (sparse fixpoint)
#------------------------------------------------------------------------------
include("logic/ir.jl")
include("logic/rule_parser.jl")
include("logic/sparse/relations.jl")
include("logic/sparse/engine.jl")

#------------------------------------------------------------------------------
# Dense helper (optional)
#------------------------------------------------------------------------------
include("tensor/labeledtensor.jl")
include("tensor/ops.jl")

#------------------------------------------------------------------------------
# Expression compiler path (tutorial-style)
#------------------------------------------------------------------------------
include("expr/context.jl")
include("expr/ast.jl")
include("expr/strategies.jl")
include("expr/parser.jl")

# dense execution backends/planners (used by eval_dense)
include("tensor/backend.jl")
include("tensor/planner.jl")
include("tensor/contract.jl")

include("expr/eval_dense.jl")
include("expr/graph.jl")
include("expr/validate.jl")
include("expr/json.jl")

export
    # rule-program surface + engine
    parse_tensorlogic, parse_datalog, parse_equations,
    Term, Var, Const, Atom, Rule, IRProgram, arity, is_fact,
    TLContext, intern!, object_symbol, declare_relation!, relation_tuples, run!,

    # dense helper
    LabeledTensor, join_project_dense,
    DenseBackend, BroadcastBackend, broadcast_backend, resolve_backend,
    ContractionPlanner, GreedyPlanner, greedy_planner, ContractionPlan, plan_contraction,

    # expression compiler + evaluation
    TLExpr, TLTerm, VarT, ConstT, Pred,
    pred, and_, or_, not_, imply, exists, forall,
    CompilerContext, add_domain!, declare_predicate!,
    CompilationConfig, soft_differentiable, hard_boolean, fuzzy_godel, fuzzy_product, fuzzy_lukasiewicz, probabilistic,
    parse_tlexpr, eval_dense,
    TLGraph, GraphNode, compile_graph, graph_stats, export_dot,
    ValidationReport, validate_expr,
    export_json, export_json_obj

end # module