---
slug: merged-branch-auto-cleanup
status: proposed
complexity: quick
orianna_gate_version: 2
tests_required: true
owner: karma
concern: work
created: 2026-04-23
---

# Merged-branch auto-cleanup

## Context

After PRs merge on GitHub, local branches and `git worktree` directories accumulate in the two Git-worktree-driven repos: `missmp/company-os` (primary — checked out at `~/Documents/Work/mmp/workspace/company-os`) and `harukainguyen1411/strawberry-agents` (this repo). Today Sona and Evelynn must remember to run cleanup manually, which does not happen reliably. Duong wants this automated.

An existing helper already does most of the work: `scripts/prune-worktrees.sh` iterates `git worktree list --porcelain`, skips dirty worktrees and detached HEADs, and prunes worktrees whose branch is merged into `main` or whose remote branch is gone. It has `--prune` (opposite of dry-run by default). See `scripts/prune-worktrees.sh` lines 11-14, 67-75, 78-98. <!-- orianna: ok -- existing helper path referenced for augmentation -->

Two gaps remain: (1) it only checks `branch --merged main` locally, missing squash/rebase-merged PRs where the commit SHA differs; (2) it is not wired into `/end-session`, so it does not fire automatically. This plan closes both gaps with a thin gh-PR-aware cleanup entrypoint plus skill-level wiring. It also enables GitHub's "Automatically delete head branches" on both target repos so the remote side self-cleans.

Out of scope: full subsume of `prune-worktrees.sh` (keep it as the local-merge-check path); `git` hook installation (optional, deferred).

## Decision

- Add a new entrypoint `scripts/cleanup-merged-branches.sh` that uses `gh pr list --state merged --json headRefName,number,mergedAt` to identify branches whose PR merged on GitHub, then delegates per-branch worktree/branch deletion to the same removal logic as `prune-worktrees.sh`. This handles squash/rebase merges that `branch --merged` misses.
- Keep `prune-worktrees.sh` as-is. The new script complements it and can be run in either repo by `cd`'ing or passing `--repo <dir>`.
- Enable `delete_branch_on_merge=true` on `missmp/company-os` and `harukainguyen1411/strawberry-agents` via `gh api` (one-time; Ekko or Duong executes).
- Wire into both `/end-session` and `/end-subagent-session` skills as a final non-fatal step (cleanup failures must never block session close).

## Tasks

- T1 — kind: script, estimate_minutes: 45. Files: `scripts/cleanup-merged-branches.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: POSIX-portable bash per Rule 10. Flags: `--repo <dir>` (default: cwd), `--dry-run` (default), `--apply` (opposite), `--limit N` (default 50). Steps: (1) `cd` to repo, (2) `git fetch --all --prune`, (3) `gh pr list --state merged --limit "$LIMIT" --json headRefName,number,mergedAt` — parse with `jq -r '.[].headRefName'`, (4) for each merged branch name: skip if it equals the current checked-out branch in the primary worktree; if a worktree path is associated with that branch via `git worktree list --porcelain`, run `git -C <path> status --porcelain` and skip-with-warning if dirty, else `git worktree remove <path>` (no `--force` — rely on clean check); then `git branch -d <branch>` (never `-D`). (5) Report summary (removed / skipped-dirty / skipped-current / not-found). Exit 0 on success; non-zero only on unexpected failure (missing `gh`, missing `jq`, repo not a git repo). DoD: dry-run on both target repos prints a non-empty candidate list and does not mutate state; `--apply` removes at least one stale worktree+branch pair when one exists; dirty worktrees always skipped; script passes `shellcheck -s bash`.
- T2 — kind: test, estimate_minutes: 45. Files: `scripts/tests/test-cleanup-merged-branches.sh` (new). <!-- orianna: ok -- prospective test path, created by this plan --> Detail: bats-free shell test harness matching the style of `scripts/tests/` siblings. Set up a throwaway git repo under `$(mktemp -d)` with two branches + two worktrees, stub `gh` via a `PATH`-shadow script that emits fixed JSON naming one of the branches as merged. Cases: (a) dry-run reports the merged branch without mutating; (b) `--apply` removes the merged worktree and branch but leaves the other; (c) dirty worktree for the merged branch is skipped and exit 0; (d) current-checkout branch never deleted. DoD: test file is executable, runs green locally, and is wired into `scripts/test-hooks.sh` or a new invocation line so CI picks it up. Invariant protected: cleanup never deletes a branch whose PR is not reported merged by `gh`, and never touches dirty worktrees.
- T3 — kind: wiring, estimate_minutes: 20. Files: `.claude/skills/end-session/SKILL.md`, `.claude/skills/end-subagent-session/SKILL.md`. Detail: add a new step near the end (after commit, before transcript archival for end-session; after commit for end-subagent-session) that runs `bash scripts/cleanup-merged-branches.sh --apply --limit 30 || true` against the session's working repo. Document that failure is non-fatal (trailing `|| true` plus a one-line note). DoD: both skill files reference the command with a non-fatal guard; smoke-run one `/end-subagent-session` closure and confirm cleanup ran without blocking.
- T4 — kind: ops, estimate_minutes: 10. Files: none (remote config change). Detail: enable auto-delete of merged head branches on both repos: `gh api -X PATCH repos/missmp/company-os -f delete_branch_on_merge=true` and `gh api -X PATCH repos/harukainguyen1411/strawberry-agents -f delete_branch_on_merge=true`. Verify with `gh api repos/<owner>/<repo> --jq .delete_branch_on_merge` returning `true`. DoD: both repos return `true`; record the verification output in the PR body of the T1-T3 implementation PR.

## Test plan

Invariants the tests in T2 protect:

- Cleanup only acts on branches GitHub reports as merged via `gh pr list --state merged`. No local-merge inference that could catch an in-flight branch.
- Dirty worktrees are never removed; the tool falls through with a clear skip message and still exits 0.
- The currently-checked-out branch in the primary worktree is never deleted.
- `git branch -d` (safe form) is always used — never `-D`. If git refuses because the branch is not fully merged in the local graph, the tool logs the refusal and continues.
- Dry-run mode mutates nothing (verified by comparing `git worktree list` and `git branch --list` pre/post).

T3 wiring is smoke-tested manually during one real `/end-subagent-session` close; no unit test required because the skill file change is declarative.

T4 is verified by the `gh api ... --jq .delete_branch_on_merge` read-back.

## Open questions

- Should we also prune fully-merged _local_ branches with no associated worktree? Current scope only acts on branches that have (or had) a worktree. Defer; Duong can decide once T1 lands.
- Optional `post-merge` git hook under `scripts/hooks/` — deferred. Skill-level wiring covers the dominant path (sessions end far more often than raw `git pull` runs bring in a merge locally).

## References

- `scripts/prune-worktrees.sh` — existing local-merge pruner, complementary. <!-- orianna: ok -- existing file, referenced as prior art -->
- `CLAUDE.md` Rule 10 — POSIX-portable bash for `scripts/` outside platform subdirs. <!-- orianna: ok -- repo-root doc reference -->
- `.claude/skills/end-session/SKILL.md` — target wiring point. <!-- orianna: ok -- existing skill file -->
- `.claude/skills/end-subagent-session/SKILL.md` — target wiring point. <!-- orianna: ok -- existing skill file -->
