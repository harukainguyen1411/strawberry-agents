# 2026-04-20 — Drive Mirror Feature Removal

## What happened

Removed the Drive mirror feature entirely (out of scope). Full sweep of all
operational scripts and live docs.

## Files deleted

- `scripts/plan-publish.sh`
- `scripts/plan-unpublish.sh`
- `scripts/test_plan_gdoc_offline.sh`
- `architecture/plan-gdoc-mirror.md`

## Files modified

- `scripts/plan-promote.sh` — stripped step 4 (Drive unpublish); updated all
  comments referencing Drive/unpublish; step numbering fixed.
- `CLAUDE.md` rule #7 — Drive-mirror justification removed; mandate to use
  plan-promote.sh preserved.
- `architecture/key-scripts.md` — removed Plan Publishing Scripts section;
  updated plan-promote.sh description.
- `architecture/platform-parity.md` — removed plan-publish and plan-unpublish
  rows.
- `agents/memory/agent-network.md` — Drive-mirror language removed from
  plan-promotion rule.
- `agents/evelynn/memory/evelynn.md` — Drive-mirror entry updated to "retired".
- `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md` — removed
  Drive re-publishing instructions from §D8 text and T9.1 task.
- `scripts/_lib_gdoc.sh` — header comment updated; gdoc::die hint updated.
- `scripts/google-oauth-bootstrap.sh` — header and verify-step updated.
- `scripts/plan-fetch.sh` — removed reference to plan-unpublish.sh.
- `scripts/orianna-sign.sh` — pre-existing unstaged fix committed here (REPO
  env override, claude-CLI check order).
- `scripts/test-orianna-lifecycle-smoke.sh` — pre-existing unstaged fix
  committed here (claim-contract setup, re-sign workflow, hermetic-plan
  frontmatter).

## Remaining hits (acceptable)

- `scripts/_lib_gdoc.sh` still has `[plan-gdoc-mirror]` log prefix and
  `google-client-id.env` path — both are used by plan-fetch.sh (Drive read,
  not Drive write mirror). These stay.
- Historical plan files (`plans/approved/2026-04-19-*`,
  `plans/in-progress/2026-04-19-*`, `plans/proposed/2026-04-19-*`) reference
  plan-publish in their task lists — these are historical records, not
  operational references. Not scrubbed.
- `agents/evelynn/memory/evelynn.md` has retirement note (intentional).

## Commit SHAs

- `51e2264` — main removal commit
- `136c3a2` — delete architecture/plan-gdoc-mirror.md
