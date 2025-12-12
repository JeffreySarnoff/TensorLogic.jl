# Expression language (dense)

This path mirrors the tutorial’s *logical operations, quantifiers, and strategy mapping*.

## Syntax

- Predicates: `knows(x,y)`
- Connectives: `& | ! ->`
- Quantifiers: `exists y:Person. expr`, `forall x:Person. expr`

Variables are identifiers starting with `_` or a lowercase letter.
Constants are identifiers starting with an uppercase letter.

## Compile to a graph

```julia
expr = parse_tlexpr("exists y:Person. knows(x,y) & likes(x,y)")
g = compile_graph(expr)

dot = export_dot(g)
json = export_json(g)
```

## Validate

```julia
ctx = CompilerContext()
add_domain!(ctx, :Person, 100)
# optionally: declare_predicate!(ctx, :knows, [:Person,:Person])

rep = validate_expr(expr, ctx)
rep.ok
rep.errors
rep.warnings
```

## Dense evaluation

```julia
ctx = CompilerContext()
add_domain!(ctx, :Person, 2)
declare_predicate!(ctx, :knows, [:Person,:Person])

inputs = Dictionary{Symbol,Any}()
set!(inputs, :knows, [0.0 1.0; 0.2 0.3])

out = eval_dense(parse_tlexpr("exists y:Person. knows(x,y)"), ctx; inputs=inputs)
out.axes   # [:x]
out.data   # Vector{Float64}
```


## Backends

`eval_dense` supports optional dense backends.

- Default: `backend=:auto` (currently `:broadcast`)
- Optional: `backend=:omeinsum` (requires installing `OMEinsum.jl`)

Example:

```julia
using TensorLogic, OMEinsum

expr = parse_tlexpr("exists y:Person. knows(x,y) & likes(x,y)")
out = eval_dense(expr, ctx; inputs=inputs, backend=:omeinsum)
```

Notes:
- The OMEinsum backend is activated only for expressions of the form `exists v:Dom. (P1 & P2 & ... & Pk)` where each `Pi` is a predicate call.
- It requires product-style AND semantics and uses einsum-style contraction only for sum/mean reductions (it will fall back otherwise).
- All other expressions use the broadcast backend.


Example with backend options:

```julia
using TensorLogic, OMEinsum

be = TensorLogic.OMEinsumBackend(; ntrials=8, slice_target=nothing)
out = eval_dense(expr, ctx; inputs=inputs, backend=be)
```
