# Issue #4 — `module_facet docInfo` skips external imports

## Goal

Stop the dependency-recursion in `module_facet docInfo` from triggering
`single` on modules that belong to packages other than the root package. This
is the single biggest compile-time saving.

## Files to change

- `lakefile.lean`

## Changes

In `module_facet docInfo (mod) : FilePath` (around line 253):

```lean
let imports ← (← mod.imports.fetch).await
-- BEFORE: fetch docInfo for every transitive import
-- AFTER : fetch docInfo only for imports in the same (root) package
let rootName := (← getRootPackage).name
let ownImports := imports.filter (fun m => m.pkg.name == rootName)
let depDocJobs := Job.mixArray <| ← ownImports.mapM fun m => fetch <| m.facet `docInfo
```

Rationale:
- doc-gen4's per-module `single` already restricts its analysis to the module
  passed on the command line (`DocGen4.Process.process` filters by
  `relevantModules`). Skipping a module's `single` invocation is therefore a
  pure subtraction; nothing else breaks.
- External modules are still loaded into the Lean environment when own
  modules import them, so own-module analysis remains correct.

## Acceptance

- `lake build DocGen4:docs` runs strictly fewer `single` invocations than
  before (visible in `lake build -v` log).
- doc-gen4 still successfully generates HTML for its own modules.
- External-decl links go through the find-redirect (consequence of #2/#3).

## Out of scope

- `coreDocs` removal — #5.
- `package_facet docInfo` trim — #7.

## Risk

- If a module-level computation needed an external module's DB row for cross
  linking, the link will degrade to find-redirect. That is the design intent.
