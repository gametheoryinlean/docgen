# Design — External-only linking for dependency and Lean-core docs

Status: **landed** on branch `external-linking`, merged via PR #11.

This document is the long-form design rationale for the change that stops
`doc-gen4` from generating HTML for external libraries (third-party
dependencies and Lean core) and instead links external references to the
Mathlib documentation site. The issue tracker (`docs/dev/issues/`) recorded
the per-step implementation work; this file consolidates the design decisions
in a single place so future readers don't need to reconstruct them from
issue comments.

## Goal

When a user runs `lake build YourLib:docs` in a project that uses doc-gen4:

1. doc-gen4 analyzes **only** the modules belonging to the user's root
   package.
2. References that point into Lean core, Mathlib, or any third-party
   dependency are emitted as links to the Mathlib documentation site
   (`https://leanprover-community.github.io/mathlib4_docs/`).
3. No HTML is generated for those external libraries; no `genCore` is run;
   no `single` is invoked for dependency modules.
4. The local search index covers only the user's own declarations.

This trades off comprehensive local search for a ~order-of-magnitude
reduction in build wall-clock and output disk usage. Concretely on
doc-gen4's own sources: 334 s → 25 s, 225 M → 1.7 M.

## Non-goals

- A configurable external base URL via `lake` option or environment variable.
  The URL is a Lean constant (`DocGen4.Output.externalDocBase`). One-line
  edit if you need to point at a different site. This is deliberate — see
  "Why a constant, not a setting" below.
- Replicating Mathlib's `declaration-data.bmp` locally. The find-redirect
  pushes resolution to the external site at click time.
- Preserving the upstream "always document Lean core + workspace deps"
  behavior behind a flag. The redesign IS the behavior.

## Architecture

### What the original code did

`lakefile.lean`'s `module_facet docInfo` recursed through every transitive
import of a module. For each import, it invoked the `single` subcommand,
which:

1. Loads the module's compiled artifact.
2. Walks `env.constants` (the entire constant table of the project +
   dependencies + core), filtering by the requested module.
3. Writes one row per declaration into the SQLite database.

`coreDocs` ran the `genCore` subcommand for each of `Init`, `Std`, `Lake`,
`Lean`, doing the same walk scoped to those roots. Because every module's
`docInfo` job depended on `coreJob`, the four core analyses also formed a
global synchronization barrier.

Then `generateHtmlDocs` invoked `fromDb` with
`rootMods.map (·.name) ++ #[`Init, `Std, `Lake, `Lean]`. `fromDb` computed
the transitive closure of imports from the DB and rendered one HTML page
per module — including hundreds of pages for the Lean core and dependency
hierarchies.

### What the redesign does

Two independent surface changes:

**Build side (`lakefile.lean`)**:

- `module_facet docInfo` filters imports to the root package
  (`mod.pkg.baseName == (← getRootPackage).baseName`). External imports
  contribute nothing to `depDocJobs`.
- `coreDocs` and `coreTarget` are deleted. `coreJob` is no longer fetched
  by `module_facet docInfo`, `package_facet docInfo`, or
  `generateHtmlDocs`.
- `package_facet docInfo` iterates `pkg.leanLibs` instead of
  `(← getWorkspace).packages.flatMap (·.leanLibs)`.
- `generateHtmlDocs` no longer appends `coreRoots` to `rootNames`.

**Output side (`DocGen4/Output/External.lean` + edits to `Base.lean` and
`DocString.lean`)**:

- New constant `externalDocBase = "https://leanprover-community.github.io/mathlib4_docs/"`.
- New `externalDeclLink (name : Name) : String` returns
  `{externalDocBase}find/?pattern={name}#doc`.
- New `externalModuleLink (mod : Name) : String` returns
  `{externalDocBase}{Module/Path}.html`.
- `moduleNameToLink` first checks `Hierarchy.contains`; if absent, returns
  `externalModuleLink`.
- `renderedCodeToHtmlAux` Step 3 ("Give up") branches now emit
  `<a href={externalDeclLink nameToSearch}>` instead of an unlinked span.
- `DocString.nameToLink?` returns `externalDeclLink name` instead of `none`
  on the two decoded-name failure paths.

**Glue (`Main.lean`)**:

- `runFromDbCmd` intersects `db.getTransitiveImports moduleRoots` with
  `linkCtx.moduleNames` so the closure is restricted to modules that were
  actually analyzed. Without this, modules that appear merely as
  `imported` rows in `module_imports` (e.g. `MD4Lean`, `SQLite`) would
  produce empty stub HTML pages because `db.loadModule` returns an empty
  module rather than failing.

### Hook-point map

| Where | What it does | Why it works |
|---|---|---|
| `DocGen4/Output/External.lean` | Holds the base URL + link constructors | Single, grep-able location for the only piece of policy in this redesign |
| `Hierarchy.contains` | Tree traversal returning `Bool` | Local-vs-external check is just membership in the modules we chose to document |
| `moduleNameToLink` | Branches on `Hierarchy.contains` | Every existing caller continues to work; external case now produces a real URL instead of a broken relative path |
| `renderedCodeToHtmlAux` Step 3 | Emits external decl link as `<a href=…>` | The "we gave up" code was the right place to inject fallback because it's the moment we know neither name nor parent nor private prefix resolved |
| `DocString.nameToLink?` | Returns `some externalDeclLink` instead of `none` | Markdown docstring `[Foo.bar]` references now resolve when `Foo.bar` belongs to a dep |
| `Main.runFromDbCmd` `targetModules` filter | Intersects closure with analyzed set | Prevents empty stub pages for the modules that only appear as import targets |
| `lakefile.lean module_facet docInfo` | Filters imports by root package | Cuts off dependency recursion |
| `lakefile.lean generateHtmlDocs` | Drops `coreRoots` | Aligns with the now-empty Lean-core DB rows |

## Why a constant, not a setting

We could expose the base URL as:

- An environment variable (e.g. `DOCGEN_EXTERNAL_BASE`).
- A Lake package option (e.g. `package_option`).
- A constant in source (`externalDocBase`).

We chose the constant for three reasons:

1. **Reproducibility.** Two CI runs of the same revision must produce
   identical output. An env var is invisible in `git log`; a Lake option
   ends up in `lakefile.lean` but is easy to override silently. A constant
   shows up in code review.
2. **Auditability.** "Where does an external link point to" is a question
   you can answer with `grep externalDocBase` in 100 ms. With a runtime
   option, the answer depends on the build environment.
3. **Yagni.** No real project we care about needs a non-Mathlib host today.
   When one does, the migration is one edit. We can promote to a setting at
   that point with a real use case to inform the API.

## Trade-offs

- The local search index (`declaration-data.bmp`) only contains the user's
  own declarations. Users searching for `Nat.add` from your site will get
  "no result" and need to use the Mathlib site's search. This is the
  intended behavior; we could synthesize external index entries later if
  it becomes a friction point.
- The find redirect adds one extra HTTP hop on click. For users behind
  high-latency links this is visible.
- A docstring `[Foo.bar]` whose target is local but mistyped used to
  silently render as unlinked text; now it produces a (failing) external
  find-redirect. Net: probably slightly worse for typo discovery, but the
  same flow always failed to surface the typo anyway — the user clicks,
  gets a "not found" on the external site.
- If you fork a project that does NOT use the Mathlib ecosystem (e.g.
  pure-Std research projects with no Mathlib bus dependency), every
  external link points at a site whose index does not contain those
  declarations. The redirect 404s. The mitigation is the constant — edit
  it to a base URL that does host your dependencies, or accept the dead
  links.

## Edge cases observed

- **Numeric tokens parsed as Names.** `decodeNameLit` accepts `"0"`, `"3"`,
  etc. as valid names. These end up in find-redirect form
  (`find/?pattern=0#doc`). Mathlib's find page fails gracefully. Not a
  regression — these tokens were already linked unhelpfully in some
  upstream paths. A follow-up could filter numeric-only tokens before
  emitting an external link.
- **Private decls.** `renderedCodeToHtmlAux` already resolves
  `_private.Foo.0.bar` to its user-facing name via
  `Lean.privateToUserName?`. Step 3 uses the resolved `nameToSearch`, so
  the find-redirect carries the user-facing name. Bare private prefixes
  with no decoded user name (anonymous prefix) still land in Step 3 and
  emit a find-redirect with the raw private name; this is rare and the
  redirect will fail, which is the same outcome as the previous "give up"
  behavior.
- **Anchor nesting.** Each external-link emission checks `innerHasAnchor`
  and skips wrapping when the inner content already contains an `<a>` tag,
  matching the existing nested-anchor guard.

## Verification

Build doc-gen4's own docs (`lake build DocGen4:docs` from project root)
and observe:

1. Total wall-clock under 30 s (vs ~5 min upstream baseline).
2. `.lake/build/doc/` size under 2 MB (vs ~225 MB upstream baseline).
3. No `Init/`, `Std/`, `Lake/`, `Lean/` directories under `.lake/build/doc/`.
4. No `MD4Lean.html`, `SQLite.html`, `BibtexQuery/`, etc. at top level.
5. A grep for `find/?pattern=` in the output finds thousands of hits,
   covering names like `Array.foldl`, `Lean.Name`, etc.
6. A grep for relative paths still finds local cross-module references
   between DocGen4 submodules.

Hosted artifact: <https://gametheoryinlean.github.io/docgen/>.

## References

- Epic: <https://github.com/gametheoryinlean/docgen/issues/1>
- PR: <https://github.com/gametheoryinlean/docgen/pull/11>
- Per-issue specs: [`docs/dev/issues/`](../issues/)
- External docs base: `DocGen4/Output/External.lean`
