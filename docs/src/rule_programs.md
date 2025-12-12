# Rule programs (sparse)

The rule-program path is designed for **huge mostly-zero relations**, without materializing dense tensors.

## Syntax

Facts:

```text
Parent[Alice,Bob].
Parent(Alice,Bob).
```

Rules:

```text
Ancestor[x,y] = Parent[x,y].
Ancestor[x,z] = Ancestor[x,y] * Parent[y,z].

# or datalog:
Ancestor(x,y) :- Parent(x,y).
Ancestor(x,z) :- Ancestor(x,y), Parent(y,z).
```

## Execution

```julia
using TensorLogic

prog = parse_tensorlogic(src)
ctx = TLContext()
run!(ctx, prog; maxiters=50)

relation_tuples(ctx, :Ancestor)
```

## Notes

- The engine computes the **least fixpoint** under forward chaining.
- Relations are stored as sets of tuples of interned ids.
