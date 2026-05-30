# External-Library Linking — Issue Tracker

Goal: stop generating documentation HTML for external libraries (third-party
dependencies + Lean core), and instead link cross-references directly to those
libraries' externally-hosted documentation at the Mathlib documentation site.

Long-form design rationale: [`docs/dev/design/external-linking.md`](../design/external-linking.md).

## Issue Order (dependency DAG)

```
#1 ── #2 ── #3 ────────────┐
                            ├── #8 ── #9
#4 ── #5 ── #6 ── #7 ──────┘
```

All implementation issues (#1–#7) merge independently; #8 is the dogfood
verification gate; #9 finalizes user-facing docs.

## Constants

- External documentation root: `https://leanprover-community.github.io/mathlib4_docs/`
- Decl link form:   `{root}find/?pattern={fullName}#doc`
- Module link form: `{root}{Module/Path}.html`

The "find redirect" form for declarations avoids needing to know the owning
module of an external declaration — the redirect is resolved client-side via
the external site's `declaration-data.bmp` (same mechanism as Zulip `docs#Foo`).

## Test Strategy

`lake build DocGen4:docs` from the project root — doc-gen4 generates its own
docs. Measure wall-clock before and after; spot-check a known reference to a
Lean core declaration (e.g. `Nat.add`) in the output HTML to confirm it points
at the Mathlib site.
