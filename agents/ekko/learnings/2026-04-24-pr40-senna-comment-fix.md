# PR #40 Senna REQUEST_CHANGES — comment accuracy fix

**Date:** 2026-04-24
**Branch:** chore/boot-unification-polish
**Commit:** e5a9c257

## What happened

Senna's REQUEST_CHANGES on PR #40 identified that the new header comments on
`scripts/mac/launch-evelynn.sh` and `scripts/mac/launch-sona.sh` claimed the
scripts "sources coordinator-boot.sh for memory consolidation and startup reads"
— but the script bodies only export env vars and exec claude directly. No
sourcing happens.

## Fix applied

Comment-only rewrite (Option A as suggested by Senna). New header text:

```
# Sets CLAUDE_AGENT_NAME / STRAWBERRY_AGENT / STRAWBERRY_CONCERN identity env
# vars inline (INV-4), then execs `claude` directly.
# Does NOT source coordinator-boot.sh — memory consolidation and startup reads
# are skipped here; they happen inside the coordinator session via SessionStart.
```

No runtime behavior touched.

## Process notes

- Worktree already existed at /private/tmp/strawberry-boot-unification-polish
- Edit, stage with git add <specific-files>, commit with STAGED_SCOPE, push
- Re-review requested via `gh pr edit 40 --add-reviewer strawberry-reviewers-2`
  (note: `gh pr review --request-review` flag does not exist; use `gh pr edit --add-reviewer`)
- Lucian's existing APPROVE is preserved (commit-scoped, but review is still on the PR)
