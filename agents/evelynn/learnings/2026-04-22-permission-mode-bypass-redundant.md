# `permissionMode: bypassPermissions` frontmatter is ignored + harmful

**Date:** 2026-04-22
**Context:** Session 2cb962cd, day-long parallel dispatch burn-in surfaced subagent permission flakiness

## What happened

Across 15+ subagent dispatches today (Syndra, Yuumi, Lucian, Talon, Jayce, Viktor — same `permissionMode: bypassPermissions` frontmatter, identical session context), permission denials appeared sporadically for Edit/Write/Bash with no recovery except fresh-session restart. Retries within the same session — even with explicit `mode: bypassPermissions` on the Agent spawn call — did not clear it. Senna (same frontmatter) worked via `--lane senna` while Lucian (same frontmatter) failed repeatedly on the default lane. Duong's hypothesis was blunt: the frontmatter flag itself might be the trigger, not a mitigator.

## What Lux found

Research (Claude Code docs + Anthropic SDK docs + GitHub issues):

1. **Under parent `auto` mode, subagent `permissionMode:` frontmatter is *ignored* by the harness classifier.** The classifier evaluates subagent tool calls against the parent's allow/deny rules, not the subagent's own declared mode. `bypassPermissions` only takes effect when the *parent* is `bypassPermissions` or `acceptEdits`. Ours is `auto` (per `.claude/settings.json defaultMode: "auto"`), so the flag is a no-op.

2. **Claude Code issue #29610** (closed "not planned") ties `bypassPermissions` on background subagents to exactly the denial pattern we saw: Read/Bash paths outside project root produce terminal denials (background agents can't prompt for user confirmation), and classifier state carries over within a single parent session — explaining both "same config, different outcome" and "restart clears it".

3. **Auto mode is explicitly designed** to return denials as recoverable tool results with recovery instructions — *not* hard session-wide lockouts. Getting `bypassPermissions` out of the way lets the normal recovery loop work.

## The fix

Strip `permissionMode: bypassPermissions` from every agent definition (`0dcb9ba`, 27 files). Rely purely on:
- `.claude/settings.json` `defaultMode: "auto"` + explicit allow-list
- Session-level `mode: bypassPermissions` on the Agent spawn call only when required

## Why this matters

- You lose *nothing* functional — the flag was already a no-op under our parent mode.
- You stop triggering the #29610 code path.
- Denials come back as recoverable tool results instead of terminal session-wide failures.
- Fewer knobs across agent defs means fewer drift vectors.

## Verification

Next large parallel-dispatch cluster is the live test. If denial rate drops below ~1/20 dispatches (vs. today's ~1/3 observed), hypothesis confirmed. If it persists, escalate to Karma's `plans/proposed/personal/2026-04-22-subagent-permission-reliability.md` diagnostic phase.

## Related learnings in this session

- **Reviewer-failure fallback:** if `scripts/reviewer-auth.sh` can't go through, the reviewer writes verdict to `/tmp/<reviewer>-pr-N-verdict.md`, Yuumi posts as PR comment under Duongntd (not a review — no approval claimed). Rule 18 only requires *one* non-author approving review, so Senna alone satisfies the gate.
- **CLI stuck recovery:** `error: An unknown error occurred (Unexpected)` or "working directory no longer exists" on `claude` invocation → `pkill -9 -f claude && pkill -9 -f 'node.*claude' && rm -rf /tmp/claude-501 && cd ~ && claude` clears it.
- **`gh pr merge --delete-branch`** exits 1 when a worktree still has the branch checked out. Merge succeeds regardless. Remove worktree first (`git worktree remove --force`).
- **Cross-lane pinch-hit** — Jayce can fix PRs on an existing in-progress plan when Talon stalls on permissions. Quick-lane is the usual chain but there's no rule against a normal-lane builder completing quick-lane work.

## References

- Claude Code Subagents docs — https://code.claude.com/docs/en/sub-agents
- Auto mode design — https://www.anthropic.com/engineering/claude-code-auto-mode
- Bug #29610 — https://github.com/anthropics/claude-code/issues/29610
- Frontmatter authoritative doc — https://github.com/anthropics/claude-code/issues/8501
- Restrictive subagent modes — https://github.com/anthropics/claude-code/issues/20264
