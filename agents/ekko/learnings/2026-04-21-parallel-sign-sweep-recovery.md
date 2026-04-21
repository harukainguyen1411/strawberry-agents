# 2026-04-21 — Parallel-agent sign sweep recovery

## Problem

When running `orianna-sign.sh` in a shared working tree with parallel agent sessions, a foreign staged
file can be swept into the signing commit, invalidating the §D1.2 single-file diff requirement.

Symptoms:
- `orianna-sign.sh` outputs "1 file changed, 1 insertion(+)" initially but git show --stat shows 2 files
- `orianna-verify-signature.sh` fails: "signing commit touches N files (must touch exactly 1)"
- `plan-promote.sh` blocks with "BLOCKED: Orianna signature invalid (gate-v2)"

## Recovery steps

1. Remove the stale `orianna_signature_<phase>:` line from the plan frontmatter using the Edit tool.
2. Commit just that removal (`git add <plan>` then commit — verify only 1 file staged).
3. Clear the staging area completely: `git restore --staged .` immediately before re-signing.
4. Run `orianna-sign.sh` immediately after clearing staging.
5. Verify the new signing commit has exactly 1 file: `git show HEAD --stat`

## Key technique: unstage-then-sign atomically

The window between `git add <plan>` inside orianna-sign.sh and the `git commit` is where contamination
happens. Clearing staging right before invoking orianna-sign.sh minimizes the window. If the sweep
recurs, unstage-and-retry.

## Edit tool + pre-commit hooks

When the Edit tool removes a line from a plan file in the `plans/approved/` subtree, the pre-commit
hook (`pre-commit-orianna-signature-guard.sh`) does NOT revert non-Orianna commits. However, if a
pre-commit hook modifies tracked files (e.g., by adding/removing content), the commit may contain
unexpected changes. Always check `git show HEAD --stat` after any commit to confirm scope.

## Parallel staging culprit pattern

During this session, `plans/proposed/personal/2026-04-21-coordinator-boot-chain-cache-reorder.md` was
repeatedly staged by a parallel agent (likely Karma batch-promote session). The pattern: another agent
calls `git add <file>` and then gets interrupted before committing, leaving the file staged. My subsequent
commits swept it in.

Prevention: `git restore --staged .` before EVERY orianna-sign.sh invocation.
