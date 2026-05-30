# Issue #8 — Dogfood: `lake build DocGen4:docs`

## Goal

Verify the redesign end-to-end by having doc-gen4 build its own documentation,
measure compile-time delta, and confirm link behavior.

Depends on: #1, #2, #3, #4, #5, #6, #7.

## Steps

### Baseline (before any change)

```sh
git stash      # or work on baseline branch
lake clean
time lake build DocGen4:docs   # record wall-clock
du -sh .lake/build/doc/        # record disk usage
```

Note the timings somewhere durable (issue comment, README, this file).

### After

```sh
git checkout external-linking
lake clean
time lake build DocGen4:docs   # expected: significantly faster
du -sh .lake/build/doc/        # expected: significantly smaller
ls .lake/build/doc             # expect NO Init/Std/Lake/Lean dirs
```

### Spot checks

Inspect a generated HTML file that references a Lean core declaration. For
example, `DocGen4/Process/Analyze.html` references `Lean.Elab.Tactic.Doc.allTacticDocs`:

```sh
grep -o 'href="[^"]*"' .lake/build/doc/DocGen4/Process/Analyze.html | \
  grep "mathlib4_docs" | head
```

Expected: at least one `href="https://leanprover-community.github.io/mathlib4_docs/find/?pattern=…#doc"` per file
that imports Lean.

Local decl spot check (`Process.AnalyzerResult` referenced from another
DocGen4 module):

```sh
grep "AnalyzerResult" .lake/build/doc/DocGen4/Output.html | head
```

Expected: relative `href="./Process/Analyze.html#…"` (or the appropriate
relative path), NOT a mathlib URL.

## Acceptance

- Build succeeds without warnings introduced by this work.
- Build wall-clock is measurably faster than baseline.
- Output disk size is smaller (no core HTML generated).
- Spot checks confirm: external → mathlib find-redirect; local → relative.

## Out of scope

- README update — #9.
