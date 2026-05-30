# Issue #2 — `moduleNameToLink` and `renderedCodeToHtmlAux` fall back to external

## Goal

When an HTML output helper encounters a name (module or declaration) that is
NOT present in the local DB, emit a link to the external Mathlib documentation
instead of either silently producing a relative path that 404s or omitting the
link entirely.

Depends on: #1.

## Files to change

- `DocGen4/Output/Base.lean`

## Changes

### `moduleNameToLink` (around line 188)

Today it unconditionally returns a relative path. Change it to first check
whether the module is local; otherwise return `externalModuleLink mod`.

The local-set check uses the `Hierarchy` already carried in `BaseHtmlContext`.
If `Hierarchy` does not expose a `contains : Name → Bool`, add a small helper
on `Hierarchy` in `DocGen4/Process/Hierarchy.lean` and use it. Implementation
sketch:

```lean
def moduleNameToLink (n : Name) : BaseHtmlM String := do
  let ctx ← read
  if ctx.hierarchy.contains n then
    -- existing path
    let parts := n.components.map (Name.toString (escape := false))
    return (← getRoot) ++ "/".intercalate parts ++ ".html"
  else
    return externalModuleLink n
```

### `renderedCodeToHtmlAux` "Step 3: Give up" branches (around lines 369–373)

Two branches currently emit `<span class="fn">` with no link. Replace both with
an `<a href={externalDeclLink name}>` wrapping the inner HTML — but only when
there is no inner anchor (preserve the existing nested-anchor guard).

```lean
-- Step 3: External fallback (was: Give up)
if innerHasAnchor then
  return (true, innerHtml)
else
  return (true, #[<a href={externalDeclLink name}>[innerHtml]</a>])
```

### Tests

Manual spot check after #8: a doc-gen4 page that mentions `Nat.add` must link
to `https://leanprover-community.github.io/mathlib4_docs/find/?pattern=Nat.add#doc`.

## Acceptance

- `lake build` succeeds.
- For doc-gen4's own modules, all anchor `<a href="…">` targets to external
  decls go through `find/?pattern=…#doc`.
- Local decls still use relative URLs (no regression).

## Out of scope

- `DocString.lean` fallbacks — that's #3.
- Build-time skipping of external modules — that's #4/#5.
