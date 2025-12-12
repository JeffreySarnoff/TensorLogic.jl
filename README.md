# TensorLogic.jl (Julia 1.12)

TensorLogic.jl implements two complementary pieces:

1) **Sparse tuple-based rule evaluation** (least-fixpoint forward chaining) for Datalog-like / bracket-rule programs.
2) **Tutorial-style expression compilation** (AST + DAG + validation + JSON/DOT export) and **dense evaluation**
   for connectives/quantifiers under selectable semantics.

The design avoids generalized Einstein summation in the core paths.

## Install / dev

```julia
] activate .
] instantiate
] test
```

## Examples

```bash
julia --project=. examples/bracket_ancestor.jl
julia --project=. examples/datalog_ancestor.jl
julia --project=. examples/tlc_like_cli.jl --output-format json "exists y:Person. knows(x,y)"
```

## Build docs

```bash
julia --project=docs -e "using Pkg; Pkg.instantiate()"
julia --project=docs docs/make.jl
```

See `docs/ABSTRACT_MODEL.md` for the refactoring contract.


## Architecture guide

The documentation includes a **Tri-map** (conceptual / mathematical / computational) that explains how the module fits together and where performance-critical pieces live.
