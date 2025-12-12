# Design

TensorLogic.jl is intentionally split into **two independent subsystems**, plus a small shared “core”:

- **Rule programs** (sparse relational semantics)
- **Expression language** (dense tensor semantics)
- **Core utilities** (Dictionaries.jl helpers and shared types)

This separation lets you use either subsystem without pulling in the other.

## 1) Rule programs (sparse fixpoint engine)

- Parse rules to an `IRProgram`
- Store relations as tuple sets (`SparseRelation{N}`)
- Forward-chain monotone rules to a fixpoint (`run!`)

This is the backend you want when relations would be extremely sparse: it avoids materializing huge mostly-zero dense tensors.

## 2) Expression language (dense)

- Parse tutorial-style expressions to a `TLExpr` AST
- Validate (domains, arities, variable binding discipline)
- Compile to a DAG (`TLGraph`) for analysis/export (DOT/JSON)
- Evaluate to labeled tensors (`LabeledTensor(data, axes)`)

The dense evaluator is semantics-driven: a `CompilationConfig` selects the concrete interpretation of connectives and
quantifiers (e.g. product/max semantics, sum/mean reductions).

### Dense execution backends

The dense evaluator supports an optional execution backend layer:

- `BroadcastBackend` (default): axis alignment + broadcasting + reductions
- `OMEinsumBackend` (optional via Julia extension): for the hot path  
  `exists v. (P1 & P2 & ... & Pk)` under product AND + sum/mean EXISTS, execute as a tensor contraction and
  (optionally) optimize contraction order via `OMEinsumContractionOrders`

When an expression does not match the hot-path preconditions, evaluation automatically falls back to `BroadcastBackend`.

## Source layout (Julia-oriented separation of concerns)

```
src/
  core/            # infrastructure (Dictionaries.jl wrappers)
  logic/           # rule programs: IR + parser + sparse engine
    sparse/
  expr/            # expression language: AST + parser + validation + eval
  tensor/          # dense tensor helpers + backends + planners
  cli/             # command-line interface
```

Guiding rule: **parsing builds data**; **semantics interprets data**; **execution runs semantics**.
