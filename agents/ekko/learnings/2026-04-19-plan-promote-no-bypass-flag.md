# plan-promote.sh has no skip-fact-check flag — use raw git mv for human overrides

**Date:** 2026-04-19
**Context:** Promoting tests-dashboard ADR past Orianna gate blocked on 11 forward-references.

## Lesson

`scripts/plan-promote.sh` intentionally has no `--no-orianna`, `--skip-fact-check`, or env-var bypass.
The comment at line 65 states: "No bypass flag. Human override: use raw git mv instead of this script."

When Duong explicitly overrides the Orianna gate, the correct procedure is:

1. Confirm the plan has no `gdoc_id` in frontmatter (if it does, run `scripts/plan-unpublish.sh` first).
2. Kill any stale `plan-promote.sh` background processes (`pkill -f plan-promote.sh`).
3. `git mv plans/proposed/<file>.md plans/approved/<file>.md`
4. Edit the frontmatter: `status: proposed` → `status: approved`
5. Commit with a body explaining the bypass reason and who authorized it.
6. Push.

## Why this matters

The script's fail-closed design is intentional — Drive orphan docs are hard to clean up.
The human-override path (raw git mv) is acceptable ONLY when Duong explicitly authorizes it
and the plan has no Drive doc, or the Drive doc has already been unpublished.
