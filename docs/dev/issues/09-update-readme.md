# Issue #9 — Update README to document the new behavior

## Goal

Document the externally-linked design for downstream users.

Depends on: #8 (no point documenting until verified to work).

## Files to change

- `README.md`

## Changes

Add a section near the top, after **Usage**, titled something like
**"External library linking"** that covers:

1. doc-gen4 no longer generates HTML for dependencies or Lean core.
2. References to external declarations link to the Mathlib doc site
   (`https://leanprover-community.github.io/mathlib4_docs/`) via the
   `find/?pattern=…#doc` redirect — same mechanism as Zulip's `docs#Foo`.
3. Implication: projects whose audience does not use the Mathlib site will
   need a different external base. (For now this requires editing
   `DocGen4/Output/External.lean`. A future change could promote it to a
   project-level config.)
4. Remove or update the existing sentence in the **Usage** section that says
   doc-gen4 always generates docs for `Init/Std/Lake/Lean` — it no longer
   does.

Also: update the "Disabling equations" / `DOCGEN_SRC` neighborhood to mention
the related design where appropriate.

## Acceptance

- README accurately reflects current behavior; nothing in README claims that
  external libs are documented.
- Markdown lint clean.

## Out of scope

- Any code change. This is documentation only.
