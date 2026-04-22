# Learning: orianna-gate-speedups in-progress → implemented promotion

**Date:** 2026-04-22
**Task:** Promote 2026-04-21-orianna-gate-speedups.md from in-progress to implemented after PR #19 merged at 98d310c.

## What Needed Fixing Before the Gate

The implemented gate blocked on two findings:

1. **`architecture_changes:` missing** — §D5 requires either `architecture_changes:` frontmatter (listing modified architecture/ files) OR `architecture_impact: none` + `## Architecture impact` section. T11 modified both `architecture/key-scripts.md` and `architecture/plan-lifecycle.md`. Fix: add `architecture_changes: [architecture/key-scripts.md, architecture/plan-lifecycle.md]` to frontmatter.

2. **`## Test results` section missing** — `tests_required: true` but no test results section. Fix: add `## Test results` with PR #19 URL and CI job URLs.

## T11.c Self-Enforcement Surprise

The body-hash guard and T11.c enforcement (bare `<!-- orianna: ok -->` rejection) that this plan itself shipped in PR #19 immediately fired on the plan's own suppressor markers when committing the body fix. Since the plan was moved via `git mv` (rename), ALL lines appear in the staged diff, triggering T11.c on every bare marker in the file.

Fix: add `-- <reason>` suffixes to all 20+ bare markers throughout the plan body. Markers in prose backticks (example text) still passed because those same lines also had a properly-reasoned marker (the `has_reason_form` check is line-level, not occurrence-level).

Exception: line 209 had `<!-- orianna: ok -->` inside backticks with no other reason-form marker on the same line. Rephrased to "suppression markers" to avoid the bare string entirely.

## Re-sign Chain Required

Because the body changed (new `## Test results` section), the existing approved+in_progress signatures were invalidated. Full re-sign chain:

1. Strip signatures + change status to proposed
2. `git mv` in-progress → proposed
3. Commit body + frontmatter fixes
4. `STAGED_SCOPE=... orianna-sign.sh ... approved` → 0 blocks → commit f734d6e
5. `plan-promote.sh ... approved` → pushed 0704211
6. `STAGED_SCOPE=... orianna-sign.sh ... in_progress` → 0 blocks → commit 3e140f3
7. `plan-promote.sh ... in-progress` → pushed f5e7958
8. `STAGED_SCOPE=... orianna-sign.sh ... implemented` → 0 blocks → commit f31232d
9. `plan-promote.sh ... implemented` → BLOCKED by staging contamination
10. Manual recovery: `git restore --staged .`, `git add implemented/`, `git rm --cached in-progress/`, commit 60a8a46 → pushed

## Staging Contamination on plan-promote.sh

The `plan-promote.sh` script does `git mv` then calls `git commit`. Between the `git mv` and `git commit`, a parallel agent staged a foreign file (`plans/proposed/work/2026-04-22-firebase-auth-loop2c-route-migration.md`). The staged-scope guard (implemented by this plan's own T11.c!) caught it and blocked the commit.

Recovery pattern when `plan-promote.sh` fails after `git mv`:
1. `git restore --staged .`
2. Inspect disk: `ls plans/implemented/personal/` — file is already there (mv completed)
3. `git add plans/implemented/personal/<plan>.md`
4. `git rm --cached plans/in-progress/personal/<plan>.md`
5. `git commit` with the standard promote message
6. `git push`

## Commit Chain

| Step | SHA | Description |
|------|-----|-------------|
| Body fix + move to proposed | 4389671 | chore: move orianna-gate-speedups back to proposed for implemented re-sign |
| Approved signature | f734d6e | chore: orianna signature for 2026-04-21-orianna-gate-speedups-approved |
| Promote to approved | 0704211 | chore: promote 2026-04-21-orianna-gate-speedups.md to approved |
| in_progress signature | 3e140f3 | chore: orianna signature for 2026-04-21-orianna-gate-speedups-in_progress |
| Promote to in-progress | f5e7958 | chore: promote 2026-04-21-orianna-gate-speedups.md to in-progress |
| Implemented signature | f31232d | chore: orianna signature for 2026-04-21-orianna-gate-speedups-implemented |
| Promote to implemented | 60a8a46 | chore: promote 2026-04-21-orianna-gate-speedups.md to implemented |

## Key Lessons

1. **Implemented gate requires `architecture_changes:` and `## Test results`** — both were missing after body fixes. Add them before signing; the gate will block without them.

2. **T11.c fires on the plan's own markers when git mv is used** — on any rename commit, all lines are staged. Budget time to add reason suffixes to all bare markers. Use `replace_all` sparingly (reasons differ per context); process each occurrence individually.

3. **plan-promote.sh git mv is not atomic with its commit** — if the commit fails (staging contamination, hook rejection), the file is already moved on disk. Recovery: manually stage the rename and commit. Do NOT re-run plan-promote.sh — it will fail with "no such file" at the old path.

4. **Body hash new value: `b372c004...`** — all three signatures use this hash.
