# Issue #1 — Add hardcoded external doc base + link helpers

## Goal

Introduce a single, well-known location for the external documentation root URL
and provide pure helper functions for constructing decl/module links. No
behavior change yet — this is the foundation for #2 and #3.

## Files to change

- **New:** `DocGen4/Output/External.lean`

## API to add

```lean
namespace DocGen4.Output

/-- External documentation root for declarations not analyzed locally. -/
def externalDocBase : String :=
  "https://leanprover-community.github.io/mathlib4_docs/"

/--
Build a link to an external declaration by name. Uses the `find` redirect so
the external site resolves the owning module client-side; we therefore do not
need to know which module the declaration belongs to.
-/
def externalDeclLink (name : Lean.Name) : String :=
  s!"{externalDocBase}find/?pattern={name}#doc"

/--
Build a link to an external module's page. Used by the private-prefix module
fallback in `renderedCodeToHtmlAux` when the extracted module is not local.
-/
def externalModuleLink (mod : Lean.Name) : String :=
  let parts := mod.components.map (Lean.Name.toString (escape := false))
  externalDocBase ++ "/".intercalate parts ++ ".html"

end DocGen4.Output
```

## Plumbing

- Add `import DocGen4.Output.External` from `DocGen4/Output/Base.lean` and
  `DocGen4/Output/DocString.lean` (will be consumed in #2 and #3).
- No `lakefile.lean` changes; the file is picked up by `lean_lib DocGen4`
  automatically because the directory is recursive.

## Acceptance

- `lake build` succeeds with no warnings related to the new file.
- No HTML output difference yet (this issue is API only).

## Out of scope

- Wiring these helpers into callers — that's #2 / #3.
