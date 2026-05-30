# Troubleshooting

Common issues and what to do about them.

## Build fails before any HTML is produced

**Most common cause:** your target library doesn't compile.

```sh
lake build YourLibraryName
```

must succeed first. doc-gen4 is fine with `sorry`-containing code but not
with code that fails to elaborate.

If you can't easily fix the underlying compile error, you can temporarily
delete `import`s of the failing files from your top-level library file —
you'll get partial documentation of the rest.

## Empty stub HTML for modules like `MD4Lean.html`, `SQLite.html`

**Cause:** you upgraded to this fork from upstream `doc-gen4`, but Lake
cached the previous per-module marker files, so the redesigned analysis
path was not re-run.

```sh
cd docbuild
lake clean
lake build YourLibraryName:docs
```

`lake clean` forces a full rebuild. The redesigned `module_facet docInfo`
no longer iterates dependency imports, and the redesigned `fromDb`
intersects the import closure with the analyzed-module set, so the stub
pages will not regenerate.

## External links 404 in the browser

**Cause:** the external decl or module is not hosted at
`externalDocBase`.

For typical Lean / Mathlib ecosystem projects this should not happen — the
Mathlib doc site hosts everything Lean core plus most common deps. If it
does happen, options:

1. Verify the declaration name in the URL is correctly formed (e.g. not
   `find/?pattern=0#doc`, which is a numeric-token edge case — see the
   [edge cases section in the design
   doc](../dev/design/external-linking.md#edge-cases-observed)).
2. If your project depends on something outside the Mathlib ecosystem,
   switch to a different external site — see
   [pointing-elsewhere.md](pointing-elsewhere.md).

## Local cross-module links 404

**Cause:** stale `navbar.html` or `index.html` from a previous build with a
different module set.

```sh
rm -rf docbuild/.lake/build/doc
lake build YourLibraryName:docs
```

This forces fresh navbar and index generation.

## Site renders but search/JS doesn't work

**Cause:** opening `index.html` via `file://` URLs. Browsers' Same-Origin
Policy blocks the JS from loading the search index over `file://`.

```sh
cd docbuild/.lake/build/doc && python3 -m http.server
```

Then open `http://localhost:8000/` in a browser.

## My library's modules aren't in the search index

**Expected.** The search index only covers modules that doc-gen4
analyzed locally. If your search box returns nothing for a name that
belongs to a dep, that's the design — switch to the Mathlib site search
for ecosystem-wide queries:
<https://leanprover-community.github.io/mathlib4_docs/>.

If your search box returns nothing for a name in YOUR project, something
else is wrong — likely the module wasn't analyzed because it wasn't reached
from your library's root. Make sure your top-level library file imports
the module (transitively is fine).

## Build is slow

If `lake build :docs` is taking more than 1–2 minutes for a small project,
something is off. Possibilities:

- You're rebuilding from `lake clean` cold, so `lake` is also compiling
  doc-gen4 and your deps. Subsequent builds will be much faster.
- You're somehow using upstream doc-gen4 (which builds Lean core + deps),
  not this fork. Check `docbuild/lakefile.toml`'s `[[require]]` entry.
- Your project is genuinely huge.

Reference numbers: building doc-gen4's own docs (12k LOC, 5 deps) takes
~25 seconds on an M-series Mac with this fork.

## Verifying a fresh install works

The fastest end-to-end smoke test:

```sh
git clone https://github.com/gametheoryinlean/docgen.git
cd docgen
lake build DocGen4:docs
ls .lake/build/doc/   # should contain DocGen4/ but not Init/Std/Lake/Lean/
cd .lake/build/doc && python3 -m http.server
```

Open `http://localhost:8000/`, click into `DocGen4 → Process → Analyze`,
and look for a `Lean.Elab.Tactic.Doc.allTacticDocs` reference. It should
link to `https://leanprover-community.github.io/mathlib4_docs/find/?pattern=Lean.Elab.Tactic.Doc.allTacticDocs#doc`.
