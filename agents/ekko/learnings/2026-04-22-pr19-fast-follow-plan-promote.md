# 2026-04-22 — PR #19 fast-follow plan promote: hook violations + parallel-agent contamination

## What happened

Promoted `2026-04-22-orianna-speedups-pr19-fast-follow.md` from proposed → approved → in-progress.

## Key learnings

### 1. pre-commit-t-plan-structure.sh still runs alongside pre-commit-zz-plan-structure.sh

The global pre-commit dispatcher runs ALL `pre-commit-*.sh` files in `scripts/hooks/` sorted alphabetically. The old hook (`pre-commit-t-plan-structure.sh`) still exists and runs before the new one (`pre-commit-zz-plan-structure.sh`). The old hook uses `index(prose, "h)") > 0` (bare string search) vs the new hook's `[0-9][[:space:]]*h\)` pattern. The bare search catches `...for the plan path)` as `h)`. Always test both hooks before committing a plan.

### 2. "h)" in task prose must be avoided entirely (old hook uses bare index search)

The word sequence `path)` anywhere in the ## Tasks section prose will trigger the old hook's "alternative time unit h)" false positive. Rephrase to avoid `h)` literally — e.g., change "the plan path)" to "the plan file" or restructure so `)` doesn't follow `h`.

### 3. Parallel agent contamination during plan-promote.sh rename step

plan-promote.sh does `git mv` + `git add` + `git commit` in sequence. During the `git add` phase, a parallel agent may also `git add` its own files. The result: the promote commit picks up foreign staged files and the staged-scope guard fires. Recovery: `git restore --staged <foreign-file>` to drop the foreign file, then `git commit` with just the plan rename.

However: if the parallel agent's commit lands in the window between the failed commit (after staged-scope guard fires) and the recovery commit, the parallel agent may have ALREADY committed the rename. In this case the plan is correctly moved to in-progress by the parallel agent's commit even though that commit has an unrelated message. The key indicator: `git ls-files` shows the plan at the target path, and `git log -- <target-path>` shows the rename commit.

### 4. Accidental revert of parallel agent's rename

When I did `git revert --no-edit HEAD` to undo my "chore: test commit", the revert reversed ALL changes in that commit — including the rename staged by a parallel agent. This moved the staged-scope plan (`2026-04-22-orianna-sign-staged-scope.md`) from approved back to proposed. The harness then denied me permission to re-promote it (different plan than authorized task). Flag this to the caller for manual fix or another Ekko session.

### 5. Empty orianna signature fields in frontmatter block re-signing

If a plan's frontmatter contains `orianna_signature_approved: ""` (empty string), `orianna-sign.sh` treats it as "already signed" and returns exit 2. Must delete the empty field before re-signing.

### 6. STAGED_SCOPE env var doesn't prevent other agents from staging into the index

STAGED_SCOPE scopes orianna-sign.sh's commit, but doesn't prevent the global git index from being contaminated by parallel `git add` calls. Always run `git restore --staged .` immediately before `git add <specific-file>` and stage+commit atomically in one compound command.

### 7. Suppressor reason regex: `<!-- orianna: ok -- [^-]` means reason must NOT start with `-`

The T11.c check in the zz hook uses `line ~ /<!-- orianna: ok -- [^-]/` — reason must start with a non-dash character. Writing `-- new file, ...` is fine (`n`); writing `-- -created-by-this-plan` would be rejected (starts with `-`). Always start the reason text with a letter or word.

## Commit chain for this task

- `6b7bcbd` — fix plan-structure violations (hook fixes, suppressors, h) rephrase)
- `c19d7fd` — orianna approved signature (gate: 0 blocks / 0 warns / 9 info)
- `0444152` — promote proposed → approved (pushed to remote)
- `5feb148` — orianna in_progress signature (task-gate: 0 blocks, 6 steps pass)
- `252e024` — promote approved → in-progress (committed by parallel agent incidentally)
