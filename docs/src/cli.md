# CLI tool

A small tutorial-style CLI script is included at `bin/tensorlogic`.

Run it from the package root:

```bash
julia --project=. bin/tensorlogic -d Person:100 "tall(x)"
julia --project=. bin/tensorlogic --output-format dot "knows(x,y)" > graph.dot
julia --project=. bin/tensorlogic --output-format json "knows(x,y)" > graph.json
julia --project=. bin/tensorlogic --validate -d Person:2 "forall x:Person. knows(x,y) -> likes(x,y)"
```

This CLI compiles expressions, can validate them, and exports stats/DOT/JSON.
It does not execute numeric backends; use `eval_dense` programmatically for that.
