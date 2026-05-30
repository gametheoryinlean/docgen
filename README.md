# `doc-gen4`

Document Generator for Lean 4 — **external-linking fork**.

> **Heads-up — this fork differs from upstream.** This fork does NOT generate
> documentation HTML for external libraries (third-party deps + Lean core).
> All such references link to the [Mathlib documentation site](https://leanprover-community.github.io/mathlib4_docs/)
> via the same `find/?pattern=…#doc` redirect that the Lean Zulip uses for
> `docs#Foo`. Build wall-clock drops ~10×; output size drops ~100×. If you
> need to document Lean core or your deps locally, use upstream
> [`leanprover/doc-gen4`](https://github.com/leanprover/doc-gen4). See
> [External library linking](#external-library-linking) for full detail.
>
> A worked example (this fork documenting itself) is live at
> <https://gametheoryinlean.github.io/docgen/>.

## Table of contents

- [Usage](#usage)
- [Requirements to run `doc-gen4`](#requirements-to-run-doc-gen4)
- [External library linking](#external-library-linking)
- [Source locations](#source-locations)
- [Disabling equations](#disabling-equations)
- [Troubleshooting](#troubleshooting)
- [Upgrading from upstream `doc-gen4`](#upgrading-from-upstream-doc-gen4)
- [How does `docs#Nat.add` from the Lean Zulip work?](#how-does-docsnatadd-from-the-lean-zulip-work)
- [Development of doc-gen4](#development-of-doc-gen4)
- [Design notes](#design-notes)

## Usage

`doc-gen4` is easiest to use via its custom Lake facet. The currently
recommended setup is a nested `docbuild` project inside your existing Lake
project.

1. Create a subdirectory within your existing Lake project called `docbuild`.
2. Create a `lakefile.toml` within `docbuild` with the following content:

   ```toml
   name = "docbuild"
   reservoir = false
   version = "0.1.0"
   packagesDir = "../.lake/packages"

   [[require]]
   scope = "leanprover"
   name = "doc-gen4"
   # If you are developing against a release candidate or a stable version `v4.x`,
   # replace `main` below by `v4.x`. If you do not use `main` keep in mind to
   # update this field as you update your Lean version.
   rev = "main"

   [[require]]
   name = "Your Library Name"
   path = "../"
   ```

3. Run `lake update doc-gen4` within `docbuild` to pin `doc-gen4` and its
   dependencies to the chosen versions.

   > **IMPORTANT:** If you depend on
   > [mathlib4](https://github.com/leanprover-community/mathlib4) run
   > `MATHLIB_NO_CACHE_ON_UPDATE=1 lake update doc-gen4` instead to mitigate
   > a small issue in mathlib's caching mechanism for now.

4. If your parent project has dependencies, run `lake update YourLibraryName`
   within `docbuild` whenever you update the dependencies of your parent
   project.

After this setup step you can generate documentation for an entire library
using:

```sh
lake build YourLibraryName:docs
```

For multiple libraries:

```sh
lake build Test:docs YourLibraryName:docs
```

`doc-gen4` only generates documentation for modules belonging to your
project's root package. External dependencies (Mathlib, Batteries, your own
deps, etc.) and Lean core (`Init`, `Std`, `Lake`, `Lean`) are NOT analyzed
and produce no HTML in your build. See [External library
linking](#external-library-linking) for how references to those declarations
resolve.

The root of the built docs will be `docbuild/.lake/build/doc/index.html`.
Due to the "Same Origin Policy", the generated website will be partially
broken if you open the generated HTML files directly in your browser. Serve
them from an HTTP server instead, e.g.:

```sh
cd docbuild/.lake/build/doc && python3 -m http.server
```

## Requirements to run `doc-gen4`

To compile, `doc-gen4` requires:

- A Lean 4 or `elan` installation.
- A C compiler on Linux / macOS (Windows uses Lean's bundled clang).

For `lake build YourLibraryName:docs` to work, your target library must
build (`lake build YourLibraryName` exits clean). `sorry`-containing code is
fine; **uncompilable** code is not. If the target library doesn't compile,
documentation generation will fail and you'll be left with partial build
artefacts in `docbuild/.lake/build/doc`.

If you're working on a project that only partially compiles, you can
temporarily remove `import`s of the failing files (and of files that
transitively reference them) from your top-level library file. You'll get
incomplete but working documentation of the rest of the project. We don't
recommend this as a long-term workflow — fix the underlying compile issues,
or `sorry`-out blockers, and keep your top-level library compiling.

## External library linking

To keep documentation builds fast and outputs small, this fork does not
generate HTML pages for external libraries. Instead, any reference to a
declaration or module that doc-gen4 did not analyze locally is rewritten to
point at the Mathlib documentation site:

- **Decl reference:** `https://leanprover-community.github.io/mathlib4_docs/find/?pattern=<fullName>#doc`
  — the same mechanism the Lean Zulip uses for `docs#Foo`. The external
  site's `declaration-data.bmp` + `find.js` resolve the owning module
  client-side, so doc-gen4 doesn't need to track external module ownership.
- **Module reference:** `https://leanprover-community.github.io/mathlib4_docs/<Module/Path>.html`.

The Mathlib documentation site hosts the entire Lean core (`Init`, `Std`,
`Lake`, `Lean`) plus Mathlib and most commonly-used dependencies, so this
covers the typical Lean 4 ecosystem.

### Trade-offs

- Build wall-clock is roughly an order of magnitude faster than analyzing
  every dependency, and disk usage drops by a similar factor. Measured on
  doc-gen4's own sources: **334 s → 25 s** wall-clock, **225 M → 1.7 M**
  output.
- The local search index only finds declarations in your own modules. To
  search the Lean / Mathlib ecosystem, users go to the Mathlib site's
  search.
- The find redirect adds one extra HTTP hop when a user clicks an external
  link.
- For projects whose audience does NOT use the Mathlib ecosystem (a pure
  Std research codebase, an internal-only project), external links will
  404. See [Pointing at a different external site](docs/usage/pointing-elsewhere.md).

### Pointing at a different external site

See [`docs/usage/pointing-elsewhere.md`](docs/usage/pointing-elsewhere.md).
Short version: edit the `externalDocBase` constant in
`DocGen4/Output/External.lean` and rebuild.

## Source locations

Source locations default to guessing the GitHub repo for the library, but
different schemes can be used by setting the `DOCGEN_SRC` environment
variable. For example, to open the local source file in VSCode:

```sh
DOCGEN_SRC="vscode" lake build YourLibraryName:docs
```

| `DOCGEN_SRC` | Effect |
|---|---|
| `github` *(default if unset)* | Infers the GitHub project for each library and links to the GitHub source view. |
| `file` | Creates `file://` references to local source files. |
| `vscode` | Creates [VSCode URLs](https://code.visualstudio.com/docs/editor/command-line#_opening-vs-code-with-urls) to local source files. |

## Disabling equations

Generation of equations for definitions is enabled by default; disable it
by setting `DISABLE_EQUATIONS=1`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `lake build :docs` fails before producing any HTML | Target library doesn't compile | Run `lake build YourLibraryName` first; fix the underlying compile error. |
| Build succeeds but external links 404 in browser | The Mathlib site doesn't host your dep | Edit `externalDocBase` (see [pointing-elsewhere](docs/usage/pointing-elsewhere.md)). |
| Empty HTML pages for things like `MD4Lean.html`, `SQLite.html` | Stale doc-gen4 binary (pre-fix) cached by Lake | `lake clean` inside `docbuild`, then rebuild. |
| Cross-module local links 404 | Stale `index.html` / `navbar.html` from a previous build with a different module set | Delete `.lake/build/doc/` (or run `lake clean`) and rebuild. |
| Generated site renders but JS / search broken | Opening `index.html` directly via `file://` | Serve via `python3 -m http.server` (see [Usage](#usage)). |
| Want to verify it actually works | — | Browse the dogfooded build of this fork: <https://gametheoryinlean.github.io/docgen/>. |

More detail in [`docs/usage/troubleshooting.md`](docs/usage/troubleshooting.md).

## Upgrading from upstream `doc-gen4`

If you previously used [upstream
doc-gen4](https://github.com/leanprover/doc-gen4) and want to switch to
this fork:

1. Update your `docbuild/lakefile.toml` `[[require]]` entry to point at this
   fork instead of `leanprover/doc-gen4`. If pinning via Reservoir / scope
   isn't set up for this fork, point at the GitHub URL directly:

   ```toml
   [[require]]
   name = "doc-gen4"
   git = "https://github.com/gametheoryinlean/docgen"
   rev = "main"
   ```

2. Run `lake update doc-gen4` within `docbuild`.
3. Run `lake clean` within `docbuild` (force a full rebuild — without this,
   stale per-module marker files prevent the redesign from taking effect).
4. Run `lake build YourLibraryName:docs`.

Expected differences after upgrade:

- Build is significantly faster and produces a much smaller `doc/`
  directory.
- No more `Init/`, `Std/`, `Lake/`, `Lean/` subdirectories or HTML for them.
- References that previously linked to local Lean-core HTML now link to
  `https://leanprover-community.github.io/mathlib4_docs/find/?pattern=…#doc`.
- Your search box only finds declarations in your own modules.

If anything regresses, revert to upstream.

## How does `docs#Nat.add` from the Lean Zulip work?

If someone sends a message containing `docs#Nat.add` on the Lean Zulip,
this auto-links to `Nat.add` in the Mathlib4 documentation. The mechanism
is the `/find` redirect:

`https://example.com/path/to/docs/find/?pattern=Nat.add#doc`

For Mathlib this ends up resolving to
`https://leanprover-community.github.io/mathlib4_docs/find/?pattern=Nat.add#doc`
which the page's `declaration-data.bmp` + `find.js` then redirect to the
real declaration page.

This fork uses the same redirect form to link external decls — see
[External library linking](#external-library-linking).

## Development of doc-gen4

To build docs using a locally-modified `doc-gen4`, replace the `doc-gen4`
require in your `docbuild/lakefile.toml`:

```toml
[[require]]
name = "doc-gen4"
path = "../../path/to/your/doc-gen4"
```

> Note: if you modify the `.js` or `.css` files in `doc-gen4`, they won't
> necessarily be copied over when you rebuild the documentation. Either
> manually copy the changes to `docbuild/.lake/build/doc`, or do a full
> recompilation (`lake clean` and `lake build` inside the `doc-gen4`
> directory).

## Design notes

For the design rationale behind the external-linking redesign, hook points,
trade-offs, and edge cases, see
[`docs/dev/design/external-linking.md`](docs/dev/design/external-linking.md).

The per-issue implementation specs are under
[`docs/dev/issues/`](docs/dev/issues/).
