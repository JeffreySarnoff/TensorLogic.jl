# API

## Rule programs

```@docs
TensorLogic.parse_tensorlogic
TensorLogic.TLContext
TensorLogic.run!
TensorLogic.relation_tuples
```

## Expression language

```@docs
TensorLogic.parse_tlexpr
TensorLogic.compile_graph
TensorLogic.export_dot
TensorLogic.export_json
TensorLogic.validate_expr
TensorLogic.eval_dense
TensorLogic.resolve_backend
```

## Types

```@docs
TensorLogic.IRProgram
TensorLogic.Atom
TensorLogic.Rule
TensorLogic.CompilerContext
TensorLogic.CompilationConfig
TensorLogic.LabeledTensor
TensorLogic.ValidationReport
TensorLogic.GreedyPlanner
TensorLogic.plan_contraction
```
