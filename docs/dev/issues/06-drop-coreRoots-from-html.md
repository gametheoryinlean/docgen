# Issue #6 — Drop `coreRoots` from `generateHtmlDocs`

## Goal

Without `coreDocs` (#5) the DB has no core module rows; passing `coreRoots` to
`fromDb` would attempt to generate HTML for empty modules. Remove them.

Depends on: #5.

## Files to change

- `lakefile.lean`

## Changes

In `generateHtmlDocs` (around line 370):

```lean
-- BEFORE
let coreRoots := #[`Init, `Std, `Lake, `Lean]
let rootNames := rootMods.map (·.name) ++ coreRoots

-- AFTER
let rootNames := rootMods.map (·.name)
```

If `rootMods` is empty (some `lake build` configurations might produce that),
the existing `fromDb` behavior in `Main.runFromDbCmd` already covers the
empty-roots case by enumerating the DB; with #5 the DB only contains own
modules so this remains correct.

## Acceptance

- `.lake/build/doc/` after a clean build contains only own-module HTML
  directories. No `Init/`, `Std/`, `Lake/`, `Lean/`.
- The site's index navbar lists only own modules.

## Out of scope

- `package_facet docInfo` workspace trim — #7.

## Risk

- The `search` index (`declaration-data.bmp`) will only contain own decls.
  This is the intended behavior; users searching for external decls should use
  the Mathlib site's search.
