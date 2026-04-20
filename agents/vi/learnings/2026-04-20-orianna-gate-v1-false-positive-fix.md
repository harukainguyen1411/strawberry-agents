# Orianna gate-v1 false-positive fix — 2026-04-20

## Summary

Fixed three false-positive classes in `scripts/fact-check-plan.sh` (the bash fallback for grandfathered plans):

### FP1: Whitespace-in-backtick spans
- **Pattern:** `` `scripts/foo.sh exists` `` — a backtick span with a space in it
- **Root cause:** The awk extraction printed the entire backtick content as one token; `scripts/foo.sh exists` contains `/` so it passed `is_path_shaped()`; `route_path()` matched the `scripts/*` prefix; `test -e` against `scripts/foo.sh exists` (with the space) always fails
- **Fix:** In the inline-backtick extraction loop, skip any token containing `[[:space:]]`

### FP2: path:line-number cross-references
- **Pattern:** `` `scripts/plan-promote.sh:63-86` `` — backtick with line-range annotation
- **Root cause:** Token `scripts/plan-promote.sh:63-86` was treated as a path; `test -e` against that literal string fails even though `scripts/plan-promote.sh` exists
- **Fix:** Strip `:NNN` suffix (pattern `*:[0-9]*`) from tokens before checking, using `${token%%:*}`

### FP3: Date templates with XX placeholder
- **Pattern:** `` `assessments/2026-04-XX-orianna-gate-smoke.md` ``
- **Root cause:** Existing filter only caught `*YYYY*` and `*MM-DD*`; the `XX` day placeholder wasn't filtered
- **Fix:** Added `*-XX-*|*-XX.*` to the template-placeholder skip list

## Smoke test fix

`test-orianna-lifecycle-smoke.sh` was failing PROMOTE_TO_APPROVED (and all downstream) because `plan-promote.sh` gained a repo identity guard (checks for `CLAUDE.md` with "Strawberry" in temp repo) after the last 11/11 run. Fix: copy `CLAUDE.md` from real repo into the temp smoke repo at setup time.

## Regression test

`scripts/test-fact-check-false-positives.sh` — 4 cases: FP1/FP2/FP3 no-block + REAL stale path still blocks.

## Real findings remaining (for plan owners, not our job)

After fix, `2026-04-20-orianna-gated-plan-lifecycle.md` still has 10 real blocks:
- `plans/approved/` (5x) — dir was intentionally deleted per T9.1; plan body references are historically accurate but now stale
- `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md` (2x) — plan self-references its old path; now at implemented/
- `scripts/hooks/pre-commit-plan-authoring-freeze.sh` (2x) — planned hook not yet implemented
- `agents/memory/last-session.md` (1x) — file doesn't exist

`2026-04-19-orianna-fact-checker.md` has 6 real blocks:
- `.claude/agents/orianna.md` (3x) — agent definition file not created
- `plans/approved/2026-04-09-wire-remaining-sonnet-specialists.md` (1x) — plan moved/archived
- `plans/approved/2026-04-19-public-app-repo-migration.md` (1x) — plan is in `proposed/`, not `approved/`
- `plans/approved/` (1x) — dir gone

`2026-04-17-deployment-pipeline.md` has 31 real blocks (many stale script paths: deploy.sh, test-functions.sh, etc. — planned but not implemented).

## Commit

4e2e1ed — pushed to main
