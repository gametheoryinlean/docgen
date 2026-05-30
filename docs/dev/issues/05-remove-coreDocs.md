# Issue #5 — Remove `coreDocs` (Init / Std / Lake / Lean analysis)

## Goal

Stop running `genCore` for the four Lean-core prefixes. These contribute the
largest single chunk of analysis time and are useless once external links land
in #2/#3.

Depends on: #4 (so the savings compound rather than re-blocking on `coreJob`).

## Files to change

- `lakefile.lean`

## Changes

1. Delete the `coreTarget` helper and the `coreDocs : Array FilePath` target
   (around lines 215–245).
2. Remove `let coreJob ← coreDocs.fetch` and the `coreJob.bindM` wrapper from
   `module_facet docInfo` (lines 256, 269).
3. Remove the same from `package_facet docInfo` (line 303–306) and
   `generateHtmlDocs` (line 339, 373).

Search for every remaining reference: `grep -n coreDocs\|coreJob lakefile.lean`
must return zero hits after the edit.

## Acceptance

- `lake build DocGen4:docs` succeeds with no `genCore` subprocesses (verify by
  inspecting Lake's build log or running `lake build -v`).
- HTML for `Init/Std/Lake/Lean` is NOT produced (i.e. those subdirectories
  under `.lake/build/doc/` do not exist after a clean rebuild).
- Cross-references to core decls in own docs go through find-redirect.

## Out of scope

- Removing `coreRoots` from `generateHtmlDocs` — #6.

## Risk

- The `foundational_types.html` page is still emitted. Its content references
  Lean sort/type concepts but does not link to `Sort u` etc. as decls, so it
  remains valid.
- `findJs` etc. are static assets and unaffected.
