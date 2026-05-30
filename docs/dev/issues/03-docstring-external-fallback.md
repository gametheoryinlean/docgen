# Issue #3 — `DocString.nameToLink?` falls back to external find-redirect

## Goal

When a docstring references a name (via Markdown link `[Foo.bar]` or `Foo.bar`
identifier syntax handled by `nameToLink?`) that doc-gen4 cannot resolve
locally, link it to the external find redirect instead of giving up.

Depends on: #1.

## Files to change

- `DocGen4/Output/DocString.lean`

## Changes

### `nameToLink?` (around line 39)

The final `return none` paths fire when neither global nor local-module search
finds the name. Replace those `none` returns with an external find-redirect
link. Also: the auto-generated-suffix special case that currently leaves names
"unresolved" should fall through to the same external path.

Sketch:

```lean
def nameToLink? (s : String) : HtmlM (Option String) := do
  let res ← getResult
  if s.endsWith ".lean" && s.contains '/' then
    return (← getRoot) ++ s.dropEnd 5 ++ ".html"
  else if let some name := Lean.Syntax.decodeNameLit ("`" ++ s) then
    -- (existing local resolution path unchanged) …
    -- final fallback (was: `return none` and several intermediate `none`s):
    return some (externalDeclLink name)
  else
    return none
```

Be careful: only the structured branches that decoded a `Name` should fall
back externally. Plain string fallback (the outer `else return none`) stays as
`none` — it really wasn't a name.

### Tests

After #8: a doc-gen4 module containing a docstring with `` `Nat.add `` should
produce a link to `…/find/?pattern=Nat.add#doc`.

## Acceptance

- `lake build` succeeds.
- No regressions on local docstring links.
- Previously-orphaned references in docstrings to external decls now link.

## Out of scope

- Build-time skipping — #4/#5.
- README updates — #9.
