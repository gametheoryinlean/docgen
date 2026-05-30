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
behavior is reproducible and reviewable.
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

end DocGen4.Output
