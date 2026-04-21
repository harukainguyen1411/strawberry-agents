# Sign plans before adding body sections — not after

**Date:** 2026-04-21
**Source:** Talon's Orianna Step E implementation session

## What happened

Talon implemented the `implemented`-gate section (Step E verification) for a plan that had already been signed at prior gates. Adding the new body section changed the plan's body hash, invalidating all prior Orianna signatures. The plan had to be re-signed from scratch.

## The rule

Orianna signatures bind to the plan body hash at signing time. Any content addition — including new section headers, new steps, or new tables — changes the hash and invalidates the signature.

**If a plan needs implementation-gate sections (`## Implementation`, `## Test Results`, etc.), those sections must exist as placeholders BEFORE the first `orianna-sign.sh` call.**

## When this matters

- Quick-lane plans (Karma writes them). Karma must include all gate-sections as placeholder stubs on initial draft.
- Any plan that will be extended at implementation time. Plan authors should anticipate what sections will be required later and stub them in advance.

## What does NOT invalidate

- YAML frontmatter changes (status, timestamps) — these are outside the body hash.
- Changes to gitignored or non-body files.

## Remediation if it happens

Re-run `orianna-sign.sh` at every prior gate phase in sequence and commit each signature separately. Not the end of the world, but costs time and an Orianna budget.
