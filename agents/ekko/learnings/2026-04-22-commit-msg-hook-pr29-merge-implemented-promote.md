# PR #29 merge + commit-msg-no-ai-coauthor-hook implemented promote

date: 2026-04-22
last_used: 2026-04-22

## What happened

Merged PR #29 (commit-msg hook) via `gh pr merge 29 --squash --delete-branch`. Local branch deletion error (checked-out worktree) is non-fatal — PR was merged. Pull --no-rebase fast-forwarded.

Full re-sign chain for the plan (proposed→approved→in_progress→implemented):

1. Body fix required before any signing: add `architecture_impact: none` frontmatter, `## Architecture impact` section, `## Test results` section (needs both PR URL AND an `assessments/` path anchor — PR URL alone blocks), reason suffixes on all bare `<!-- orianna: ok -->` markers, remove stale signature fields.
2. Move plan back to `proposed/personal/` and set `status: proposed` before `plan-promote.sh`.
3. Sign with `orianna-sign.sh` before `plan-promote.sh`. plan-promote.sh only works from proposed/.
4. `approved→in_progress` and `in_progress→implemented` require manual `git mv` + `status:` rewrite + commit (plan-promote.sh refuses non-proposed sources).
5. Orianna `implementation-gate-check` took ~15 minutes for this plan — be patient.

## Parallel-agent contamination incidents

- `in-progress` promote commit swept in a stale staged rename of p1-factory-build-ipad-link plan (approved→proposed). Recovery: git mv it back + commit immediately.
- `implemented` sign: contamination appeared in git index but STAGED_SCOPE auto-derived correctly to only the plan file. Clean sign commit.

## Key invariant

`git restore --staged .` before every `orianna-sign.sh` call and before every `git add` before promote commits.
