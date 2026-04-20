# Orianna `<!-- orianna: ok -->` is an unpoliced trust primitive

**Date:** 2026-04-20
**Context:** Karma's quick-lane plan for work-repo routing contained meta-example path references (`apps/demo-studio/backend/session_store.py` as an example of the bug, plus `scripts/test-fact-check-work-concern-routing.sh` as a not-yet-created test file). Orianna blocked 4 findings. Orianna's own report suggested `<!-- orianna: ok -->` suppression. Applied, re-signed, clean pass.

## Lesson

The suppression marker only bypasses **claim-contract Step C** (path-token existence). It does NOT bypass frontmatter, gating questions, sibling files, signature commit shape, carry-forward verification, structural pre-commit lint, TDD gate, or dual review on impl PRs.

But within Step C, suppression is **unlimited and unaudited**:
- No reason required (bare `<!-- orianna: ok -->` passes).
- No cap on count per plan.
- No surfacing in the signature commit trailer.
- Plans commit direct to main (Rule 4) — no PR review ever sees the markers pre-merge.

An agent authoring a plan could fabricate every path, sprinkle markers on every line, and pass all three gates vacuously. The design is honor-based.

## When this matters

- Any time a plan looks "too clean" for the paths it cites — grep for marker count.
- Post-hoc audits: `git grep '<!-- orianna: ok -->' plans/` surfaces drift.
- If commissioning a plan that describes a routing/validation bug (where meta-examples are legitimate), document the markers explicitly in the plan body so auditors don't flag.

## Mitigation candidates (not patched today)

1. Require reason: `<!-- orianna: ok <category> -->` with parser validating `<category>` against allowlist (META-EXAMPLE, FUTURE-ARTIFACT, CITED-EXTERNAL).
2. Cap count: reject plans with >N markers unless `Orianna-Bypass:` trailer (admin-only).
3. Surface in signature trailer: `Orianna-Suppressions: 4` — visible in `git log`.
4. Weekly Orianna sweep flags plans with unusual marker density.

Park for a future plan. Duong aware.
