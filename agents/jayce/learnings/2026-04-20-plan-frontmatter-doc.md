# 2026-04-20 — Plan frontmatter doc (T1.3)

## Task
Write `architecture/plan-frontmatter.md` documenting the five Orianna gate v2
frontmatter fields per plan `2026-04-20-orianna-gated-plan-lifecycle.md` T1.3.

## What I did
- Read the ADR (§D1, §D2, §D5, §D8) for the authoritative field definitions.
- Read three existing `architecture/*.md` files to match formatting conventions:
  no numbered headings, `---` horizontal rules between major sections, tables
  for attribute metadata, fenced code examples.
- Wrote the file with a field-by-field section for each of the five fields plus
  a quick-reference table and related-scripts table at the bottom.
- Committed direct to main with `chore:` prefix (non-code/docs, rule 5).

## Learnings
- The `architecture/plan-gdoc-mirror.md` and `architecture/key-scripts.md`
  files are good formatting templates for reference docs: table-heavy, short
  prose, `---` between logical sections.
- For docs tasks the xfail-first rule (CLAUDE.md rule 12) does not apply — it
  applies only to TDD-enabled services. Pure architecture docs have no test
  harness.
- Carry-forward for `orianna_signature_<phase>` is the critical detail: each
  subsequent gate must also re-verify all prior signatures, not just its own.
  This distinction belongs in the doc.
