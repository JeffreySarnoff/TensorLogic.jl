# Tri-map of the module

This page gives **three non-overlapping representations** of the package. Together they act as a *tri-directional map*:
you can navigate the system by *concepts*, by *math/semantics*, or by *computation/dataflow* and always end up at the
same implementation points.

---

## Representation A: Conceptual architecture (concerns and invariants)

### Layer 1: Languages

Two surface syntaxes, two parsers, one shared IR spirit:

- **Rule programs** (Datalog-like + bracket syntax)
  - facts and rules over *relations* (predicates as sets of tuples)
  - evaluated via a **monotone fixpoint** engine (sparse backend)

- **Expression language**
  - logical connectives, quantifiers, predicate calls
  - can be compiled to a graph, validated, exported (DOT/JSON), and evaluated (dense backend)

Invariants:
- parsing is total over the supported grammar and fails with `ArgumentError` on invalid input
- parsing *does not* allocate “execution state”; it only produces IR / AST structures

### Layer 2: Semantics

Two semantics families:

- **Relational semantics** (sparse):
  - relations are sets of tuples
  - rule bodies are joins; heads are projections
  - evaluation is monotone and converges to a least fixpoint (within `maxiters`)

- **Tensor semantics** (dense):
  - predicate calls are tensors over domains
  - connectives and quantifiers are interpreted by a `CompilationConfig` (“strategy”)

Invariants:
- sparse semantics is **idempotent** and **monotone** under set union
- dense semantics is **shape-safe**: axes represent logical variables; operations preserve axis meaning

### Layer 3: Execution backends

- sparse execution: tuple-relations and join/projection
- dense execution: broadcast backend by default; optional **OMEinsum** backend for a specific hot path

Invariants:
- backend selection never changes *which* expression is being evaluated, only *how* it is executed
- optional backends are loaded via Julia **extensions** and are not required for the core package

---

## Representation B: Mathematical semantics (algebra)

### Rule programs (sparse)

Let a relation `R` of arity `n` be a subset `R ⊆ D₁ × … × Dₙ`.

A rule of the form:

`H(t₁,…,tₙ) = B₁(...) * ... * Bk(...)`

is interpreted as:

1. **Join** the body relations on shared variables
2. **Filter** on constants
3. **Project** the resulting tuples to the head variables
4. **Union** into `H`

Repeated application yields the least fixpoint (when monotone).

### Expression language (dense)

Let predicates be tensors `P : D_{a₁} × ... × D_{a_r} → [0,1]` (typical TensorLogic setting).

A `CompilationConfig` specifies:
- `and_kind` (e.g. product)
- `or_kind` (e.g. max)
- `not_kind` (e.g. 1-x)
- `imply_kind`
- `exists_reduce_kind` (sum / mean / max)
- `forall_reduce_kind`

Evaluation maps each expression to a **labeled tensor** `(data, axes)` where axes are variable symbols.

Key property used for optimization:
- for product AND and sum/mean EXISTS, `exists v. (P₁ & ... & Pk)` can be executed as a **tensor contraction**
  where `v` is **omitted from the output indices** (contract-and-reduce).

---

## Representation C: Computational pipelines (dataflow)

### Pipeline 1: sparse rules

`String` → `parse_tensorlogic` → `IRProgram` → `run!` → `TLContext(relations)` → `relation_tuples`

Hot spots:
- join/projection in `logic/sparse/engine.jl`
- relation storage in `logic/sparse/relations.jl`

### Pipeline 2: expressions (analysis tools)

`String` → `parse_tlexpr` → `TLExpr` → (`compile_graph`, `validate_expr`, `export_dot/export_json`)

Hot spots:
- AST builder (`expr/parser.jl`)
- validator (`expr/validate.jl`)

### Pipeline 3: expressions (dense execution)

`TLExpr` + `CompilerContext` + inputs → `eval_dense` → `LabeledTensor`

Execution choices:
- broadcast backend (axis alignment + broadcasting + reductions)
- optional OMEinsum backend:
  - detect the EXISTS-conjunction hot path
  - plan/order contraction
  - (optionally) optimize order using OMEinsumContractionOrders when installed
  - cache optimized contraction code
