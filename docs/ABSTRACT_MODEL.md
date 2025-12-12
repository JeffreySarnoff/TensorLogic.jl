# Abstract model

This is the single-source semantic specification for the package. For a complementary architectural and computational view, see **Tri-map**.


This document is the **single source of truth** for the *meaning* and *shape* of TensorLogic.jl.
Any refactor / rewrite is correct iff it preserves the contracts below.

## 1. Two user-facing entry points

TensorLogic.jl deliberately offers **two independent entry points**:

### A. Rule programs (sparse, fixpoint)
- Surface: Datalog-like and/or bracket “tensor equation” rules.
- Compilation: `parse_tensorlogic(::String) -> IRProgram`.
- Execution: `run!(::TLContext, ::IRProgram)` computes the **least fixpoint** under monotone forward chaining.
- Storage: relations are sets of tuples of interned ids (no dense tensor materialization).

### B. Expression programs (dense, tutorial-style)
- Surface: tutorial-style expressions with connectives and quantifiers:
  `& | ! -> exists forall`
- Compilation: `parse_tlexpr(::String) -> TLExpr`, then `compile_graph(::TLExpr) -> TLGraph`.
- Evaluation: `eval_dense(::TLExpr, ::CompilerContext; inputs, config, consts)` evaluates to a `LabeledTensor`
  (dense semantics, no generalized einsum).

These two entry points share terminology but do **not** need to share execution engines.

## 2. Core data model

### 2.1 Sparse fixpoint engine

- `TLContext` maintains:
  - `obj2id :: Dictionary{Symbol,Int}` and `id2obj :: Vector{Symbol}`
  - `rels  :: Dictionary{Symbol,Any}` mapping predicate -> `SparseRelation{N}`

- `SparseRelation{N}` stores:
  - `tuples :: Set{NTuple{N,Int}}`

**Invariant S1 (interning):** `object_symbol(ctx, intern!(ctx, s)) == s`.

**Invariant S2 (arity):** each predicate name maps to exactly one arity. Conflicts are errors.

**Semantics S3:** `run!` is monotone and returns the least fixpoint for a finite domain.

### 2.2 Dense expression compiler

- `CompilerContext` maintains:
  - `domains :: Dictionary{Symbol,Int}`
  - `pred_domains :: Dictionary{Symbol,Vector{Symbol}}` (predicate signature)

- `TLExpr` AST supports:
  - `Pred`, `AndExpr`, `OrExpr`, `NotExpr`, `ImplyExpr`, `ExistsExpr`, `ForallExpr`.

- `CompilationConfig` selects a *connective semantics* (strategy):
  - `soft_differentiable`, `hard_boolean`, `fuzzy_godel`, `fuzzy_product`, `fuzzy_lukasiewicz`, `probabilistic`.

**Invariant D1 (shape):** for each `Pred(name,args)` the input tensor rank equals arity, and each axis length equals
the declared domain size for that argument.

**Invariant D2 (axes):** dense evaluation outputs a `LabeledTensor` whose axes are exactly the free variables of the expression.

**Semantics D3 (no einsum):** dense evaluation uses explicit axis alignment, pointwise operators, and reductions.

## 3. Non-functional constraints

### Julia 1.12 performance contract
- no global mutable state in hot paths
- stable types in inner loops
- tuple rows are `NTuple` of `Int`
- optional dense utilities must remain isolated from sparse fixpoint path

### Collections contract
- No `Base.Dict` in `src/`.
- Use `Dictionaries.Dictionary` for associative maps.

### Error model
- syntax errors must be explicit and local
- arity/signature mismatches are errors
- validation produces a structured report (`ValidationReport`)

## 4. Extensibility points

- add new surface syntax by compiling to `IRProgram` (rule path) or `TLExpr` (expression path)
- add new strategies by extending the operator mapping functions in `compiler/strategies.jl`
- add sparse weighted semantics via a new relation type, keeping the `run!` monotone shape


## Dense backends and planners

The expression-language subsystem separates **semantics** (logical connectives and quantifiers under a `CompilationConfig`)
from **execution**.

- `DenseBackend` selects a concrete contraction engine for a specific hot path:
  `exists v. (P1 & P2 & ... & Pk)` where each `Pi` is a predicate call, AND uses product semantics,
  and `exists` reduces by `sum` or `mean`.
- `ContractionPlanner` selects a pairwise contraction order (default `GreedyPlanner`) used by backends that do not
  optimize contraction order automatically.
- When the preconditions are not met, evaluation falls back to the broadcast backend (axis alignment + broadcasting).

Correctness note: this optimization assumes tensors represent non-negative truth-values (typical in TensorLogic-style
models), so that reordering products and sum/mean reductions does not change results beyond floating-point rounding.


### OMEinsum execution details

If `backend=:omeinsum` is selected and the OMEinsum extension is active, the evaluator will:
- build a direct einsum that omits the quantified variable from the output indices (contract-and-reduce),
- optionally optimize order using OMEinsumContractionOrders when installed,
- cache optimized contraction codes keyed by index pattern and domain sizes.
