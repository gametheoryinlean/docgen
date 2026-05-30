# Pointing at a different external documentation site

The default external documentation root is the Mathlib doc site:

```
https://leanprover-community.github.io/mathlib4_docs/
```

This is hardcoded as the `externalDocBase` constant in
[`DocGen4/Output/External.lean`](../../DocGen4/Output/External.lean).
**Why a constant and not an environment variable?** Reproducibility,
auditability, and YAGNI — see
[`docs/dev/design/external-linking.md`](../dev/design/external-linking.md#why-a-constant-not-a-setting).

## When you need to change it

You want to swap the base URL if:

- Your project's audience uses a different documentation host (a private
  mirror, a fork of the Mathlib site, an entirely separate ecosystem's
  docs).
- You're deploying your project's docs into an environment where the public
  Mathlib site is unreachable.

You DON'T need to change it if your project is a normal Lean / Mathlib
ecosystem citizen — the default just works.

## How to change it

1. Open `DocGen4/Output/External.lean`.
2. Edit `externalDocBase` to your target URL. **It must end with a trailing
   slash.**
3. Rebuild `doc-gen4` (or run `lake clean` in your `docbuild` if you're
   consuming this fork as a dep — see [Troubleshooting](troubleshooting.md)).

Example:

```lean
def externalDocBase : String :=
  "https://docs.example.org/lean/"
```

After this, all external decl links resolve as
`https://docs.example.org/lean/find/?pattern=<fullName>#doc` and external
module links as `https://docs.example.org/lean/<Module/Path>.html`.

## Requirements on the target site

For the links to actually work, the target site needs to be a doc-gen4-style
site:

- A `find/index.html` page that accepts `?pattern=<fullName>#doc` and
  redirects to the right declaration.
- A `declarations/declaration-data.bmp` so the find page can resolve the
  pattern client-side.
- Per-module HTML pages at `<Module/Path>.html`.

Mathlib's documentation site satisfies all of this and updates daily. A
private mirror that ran `doc-gen4` on the same set of upstream sources will
also satisfy this.

If your target site doesn't have a find redirect, external decl links will
404. You could mitigate by emitting direct module links instead of
find-redirect links — that requires a code change in `externalDeclLink`,
not just the URL constant.

## When in doubt

Build doc-gen4's own docs, browse the result, click a link to a Lean-core
declaration, and check that the redirect lands where you expect:

```sh
lake build DocGen4:docs
cd .lake/build/doc && python3 -m http.server
# Open http://localhost:8000/DocGen4/Process/Analyze.html in a browser,
# click on `Lean.Name`, verify it resolves.
```
