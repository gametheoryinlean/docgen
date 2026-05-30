# Issue #7 — `package_facet docInfo` restricted to root package

## Goal

`package_facet docInfo` currently flattens `ws.packages.flatMap (·.leanLibs)`,
i.e. it pulls in the libraries of every package in the workspace including
dependencies. Restrict to the root package's libraries.

Depends on: #4 (so `module_facet docInfo` already short-circuits, making this
trim a small additional safeguard rather than the load-bearing change).

## Files to change

- `lakefile.lean`

## Changes

```lean
package_facet docInfo (pkg) : FilePath := do
  let allLibs := pkg.leanLibs   -- was: (← getWorkspace).packages.flatMap (·.leanLibs)
  let libDocJobs := Job.collectArray <| ← allLibs.mapM (fetch <| ·.facet `docInfo)
  let dbPath := pkg.buildDir / "api-docs.db"
  libDocJobs.mapM fun _ => return dbPath
```

(After #5 there is no `coreJobs` either; the wrapping `coreJobs.bindM` should
be gone.)

## Acceptance

- Building `pkg:docInfo` only schedules root-package library docInfo. Verify
  with `lake build -v pkg:docInfo` (or by checking that the build doesn't
  recurse into dependency packages).

## Out of scope

- Anything in `Main.lean`.

## Risk

- A project that legitimately has multiple in-workspace projects relying on
  this facet to populate cross-package docs would lose coverage. That is the
  design intent for this redesign.
