# PR #45 — subagent git identity universalisation — REQUEST CHANGES

**Date:** 2026-04-24
**PR:** harukainguyen1411/strawberry-agents#45
**Branch:** `talon/subagent-git-identity-as-duong`
**Verdict:** CHANGES_REQUESTED

## Summary

Reviewed the Talon-authored (but Orianna-committed) fix to universalise subagent git identity rewriting across both personal-concern and work-scope worktrees. Core precedence fix is correct, but three real bypass paths in the Bash hook defeat the stated invariant.

## Critical findings

- **C1** `git -c user.email=X commit` — inline `-c` config override bypasses the hook. Reproduced locally against PR-branch hook content.
- **C2** `GIT_AUTHOR_EMAIL=X git commit` — inline env-var prefix bypasses the hook.
- **C3** `git commit --author="..."` — `--author` flag produces split author/committer; author still leaks.

The hook detects `git commit` at the command level but only rewrites worktree config, which is the *lowest* precedence layer. Inline `-c`, env vars, and `--author=` all sit higher.

## Important findings

- **I1** Old `pretooluse-work-scope-identity.sh` left behind in tree — rename was really an addition; `.claude/settings.json` points at the new file but old file is dead-code orphan.
- **I2** Copy-paste bug: lines 103–106 of new hook re-set `user.name` claiming it's the committer — git has no such key. No-op with misleading comment.
- **I3** Empty stdin → exit 2 block (fail-closed too aggressive for the empty case).

## What's solid

- Env-merge precedence fix in `agent-identity-default.sh` (`{**existing_env, **neutral_env}`) — verified to override caller-supplied persona env.
- Orianna carve-out covers all three paths: `CLAUDE_AGENT_NAME`, `STRAWBERRY_AGENT`, `subagent_type`.
- Rule 12 honored: xfail at `f525ad53` before impl at `338b8198`.

## Reviewer-lane note

Lucian also CHANGES_REQUESTED at 09:57; Senna at 09:59. Separate lanes (`strawberry-reviewers` and `strawberry-reviewers-2`) both visible — lane split working as designed post-PR-#45-incident.

## Process anomaly (flagged to Lucian, not acted on)

All three commits on the branch authored by `orianna@strawberry.local`. PR body says "Author: Talon". Not my lane to judge, noted in review.

## Testing method I wish we had standard

For identity-rewrite hooks, the test matrix MUST include:
1. Plain `git commit`
2. `git -c user.email=X commit` (inline config override)
3. `GIT_AUTHOR_EMAIL=X git commit` (inline env override)
4. `git commit --author="..."` (author flag)
5. Orianna carve-out (doesn't rewrite)

The PR's test suite covers #1 and #5 only. #2/#3/#4 are exactly the bypasses I found. Committing this pattern into future review checklists.

## Time to close

~35 min — mostly spent reproducing bypasses locally. Worth it; the verdict hinged on them.
