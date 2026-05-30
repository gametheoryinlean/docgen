/-
Copyright (c) 2026 doc-gen4 contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Lean.Data.Name

/-!
# External documentation linking

This module holds the hardcoded base URL and link constructors used when
doc-gen4 needs to refer to a declaration or module that was NOT analyzed
locally. The expected use case is that the consuming project documents only
its own modules and links every other reference (Lean core, Mathlib, other
dependencies) to the Mathlib documentation site.

The "find redirect" form for declarations is the same scheme used by Zulip's
`docs#Foo`: the external site's static `declaration-data.bmp` + `find.js`
resolve the owning module client-side, so we don't need to know it.

To point this at a different external site (e.g. a private Mathlib mirror or
an entirely different ecosystem), edit `externalDocBase` below. This is
intentionally a Lean constant rather than an environment variable so the
behavior is reproducible and reviewable. See
`docs/dev/design/external-linking.md` for the full rationale.

Callers:
- `DocGen4.Output.moduleNameToLink` — external module link when the module
  is not in the local `Hierarchy`.
- `DocGen4.Output.renderedCodeToHtmlAux` — external decl link in the Step 3
  fallback when `name2ModIdx` doesn't resolve the name.
- `DocGen4.Output.nameToLink?` — external decl link as the final fallback
  for docstring identifier references.
-/

namespace DocGen4.Output

/--
The base URL all external references resolve under. Must end with a trailing
slash. Edit this if your project targets a different external documentation
site.
-/
def externalDocBase : String :=
  "https://leanprover-community.github.io/mathlib4_docs/"

/--
Build a link to an external declaration by name using the `find` redirect.
The external site resolves the owning module client-side via its
`declaration-data.bmp`, so this works without us tracking module ownership
for external decls.
-/
def externalDeclLink (name : Lean.Name) : String :=
  s!"{externalDocBase}find/?pattern={name}#doc"

/--
Build a link to an external module's documentation page. The path follows
doc-gen4's standard convention `{Module/Path}.html` under the base URL.
-/
def externalModuleLink (mod : Lean.Name) : String :=
  let parts := mod.components.map (Lean.Name.toString (escape := false))
  externalDocBase ++ "/".intercalate parts ++ ".html"

/--
Decide whether a `Name` is worth emitting as an external find-redirect link.

The Lean pretty printer occasionally tags single-character identifiers
(bound variable names like `x`, `n`, `c`) and numeric literals (`0`, `3`)
with declaration metadata. When such a tag falls through to the external
fallback in `renderedCodeToHtmlAux`, the resulting
`find/?pattern=<token>#doc` URL is guaranteed to 404 on the external site.
We filter those out and let the caller emit an un-linked span instead.

Rule: a name is linkable if every component contains at least one
alphabetic character AND the joined display form is at least two
characters long. This keeps real short names like `Eq`, `IO`, `Id`
linkable while dropping single-character bound variables and pure-numeric
tokens.
-/
def isLinkableExternalName (name : Lean.Name) : Bool :=
  let s := name.toString
  s.length ≥ 2 && s.any Char.isAlpha

end DocGen4.Output
