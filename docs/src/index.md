# TensorLogic.jl

TensorLogic.jl provides two complementary layers:

- **Rule programs (sparse)**: parse Datalog-like / bracket rules to an IR, then run a monotone fixpoint over **relations-as-tuples**.
- **Expression language (dense)**: parse tutorial-style expressions, compile to a DAG, validate, export DOT/JSON, and (optionally) evaluate densely with configurable semantics.

The project is optimized for Julia **v1.12** and avoids generalized Einstein summation in the core implementation.

See `docs/ABSTRACT_MODEL.md` in the repository root for the refactoring contract.


## How to navigate

- If you want to understand how the package is structured, start with **Tri-map**.
- If you want the precise semantics, see **Abstract model**.
- If you want to use the package, see **Examples** and **API**.
