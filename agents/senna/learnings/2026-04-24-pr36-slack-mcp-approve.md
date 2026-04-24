# PR #36 slack-mcp migration — round 2 APPROVE

**Date:** 2026-04-24
**PR:** harukainguyen1411/strawberry-agents#36 (`chore/slack-mcp-migration` → main)
**HEAD verified:** 240161c0 (strawberry-agents) + 2ec3f99 (strawberry repo main, start.sh fix)
**Verdict:** APPROVE

## Context

Round 1: CHANGES_REQUESTED with three important findings. Round 2 re-review after author posted per-finding evidence of resolution.

## Resolutions verified

1. **Stale mcp__slack-bot__ / mcp__slack-user__ refs in agent memory.** Live routing doc `agents/memory/duong.md` on PR HEAD trimmed to name only `mcp__slack__notify_duong(text)` and explicitly forbids reconstructing routing from memory. Cross-tree grep outside `agents/*/learnings/`, `agents/*/transcripts/`, `.claude/worktrees/`, `agents/sona-or-evelynn/` returns only (a) the ekko MEMORY.md supersede-pointer block (meant to name what it replaces) and (b) the in-progress migration plan itself. Both appropriate. Historical records correctly treated as immutable.

2. **npx -y tsx cold-start network dep.** `mcps/slack/scripts/start.sh` @ 2ec3f99 now execs `./node_modules/.bin/tsx` with `[ -x ... ] || { echo "... run 'npm install' ..."; exit 1; }` guard. Verified `./node_modules/.bin/tsx` present locally. Clean local-binary fix, loud failure mode.

3. **Cross-repo TDD gate.** Confirmed 146da13 (xfail T6-T11) precedes e337328 (impl T12-T22) on strawberry feat branch. Rule 12 honored in spirit. Cross-repo CI enforcement correctly deferred as follow-up.

## Generalizable patterns

- **"Stale refs" on migration PRs split cleanly into live vs historical.** When re-reviewing migrations, scope the grep with explicit excludes for `agents/*/learnings/` + `agents/*/transcripts/` + `.claude/worktrees/` before flagging. Otherwise round 2 re-surfaces the same historical hits that were already correctly carved out in round 1.
- **Supersede-pointer blocks legitimately name the old identifiers.** The ekko MEMORY.md:154 block reads as a stale ref on naive grep but is doing exactly the right thing — telling future readers what was replaced. Recognizing this pattern on sight avoids false-positive churn.
- **Cross-repo TDD gates are an operational gap worth flagging but not blocking.** The pre-push hook runs local to each repo; migrations that span sibling repos can honor the discipline in spirit (commit order on the feat branch) without CI enforcement. Informational-severity is the right call.

## Review URL

Posted as `strawberry-reviewers-2` APPROVED; URL not returned by `gh pr view --json reviews` (GitHub quirk — review ID resolvable via `gh api`).
