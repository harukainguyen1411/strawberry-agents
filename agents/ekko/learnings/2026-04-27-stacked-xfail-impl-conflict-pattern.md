---
date: 2026-04-27
topic: stacked xfail → impl conflict pattern on feat/* branches
---

# Stacked xfail → impl conflict pattern

## Situation

ADR-2 used a two-PR strategy: PR #121 commits xfail stubs into the base branch
(`feat/demo-studio-v3`), then PR #122 adds the real impl on a separate branch
forked before #121 merged. When #121 merges, the base gains stub versions of
the same files the impl branch owns (e.g. `sse.go`, `run.go`, `handler_test.go`).
GitHub reports `mergeStateStatus: DIRTY, mergeable: CONFLICTING`.

## What happens

- Git auto-merges most files cleanly (new-file additions from base land fine).
- Files the impl branch **modified** that the base now also has as stubs get a
  real `CONFLICT (content)` — git can't auto-pick because both sides have content.
- `handler_test.go` was the only real conflict on PR #122: base had `t.Skip(...)` stubs,
  impl branch had full test bodies. Resolution: `git checkout --ours` (keep impl branch).

## Resolution pattern

1. `git merge origin/<base>` in the worktree — expect conflict on shared impl files.
2. For stub-vs-real conflicts: `git checkout --ours <file>` — the impl always wins.
3. For additive conflicts (e.g. two PRs adding different env vars to the same line in
   `deploy.sh`): manually combine both additions into the resolved line.
4. `bash -n <script>` to syntax-check any shell files touched.
5. Run the package test suite before pushing.
6. Commit the merge, push, then `gh pr merge --squash`.

## Hook note

The PreToolUse hook blocked `git merge` in worktrees when the call wasn't in the
original task scope. Needs explicit authorization from the coordinator before
running merge resolution on shared worktrees. Phrase clearly in blocker report:
"need authorization to run `git merge origin/<base>` in worktree at <path>".

## Squash prefix rule

`tools/**` paths → `chore:` prefix at squash-merge title, NOT `feat:`. The pre-push
hook enforces diff-scope ↔ commit-type; `feat:` on a `tools/**`-only diff will fail.
