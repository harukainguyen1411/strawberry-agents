# agent_type from hook JSON is the reliable Orianna identity signal (Agent-tool dispatches only)

**Date:** 2026-04-23
**Source:** PR #32 — subagent identity propagation
**Session shard:** 26406c02

## The finding

When Evelynn dispatches Orianna via the Agent tool (`subagent_type: "orianna"`), the Claude Code harness injects `.agent_type` into the hook JSON payload received by PreToolUse hooks. This field is not spoofable the way git-author identity is — it comes from the harness, not from a shell script.

PR #32 (`fc96916`) rewired `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` to read `.agent_type` as the primary identity source (fallback: git author string). The guard now correctly permits plan promotions dispatched through the Agent-tool Orianna path.

## The limitation

Script-invoked worktree sessions (`.claude/worktrees/agent-*` CLI context, as used in batch plan-promote runs) do NOT populate `agent_type`. The harness only injects this field for Agent-tool spawns. Script-dispatch paths get `null` or absent `agent_type`, and the guard correctly blocks them (fail-closed).

This means there are now two classes of Orianna invocation:
- **Agent-tool path** (Evelynn → Agent tool → Orianna): `agent_type` = "orianna" → PERMITTED
- **Script-dispatch path** (CLI worktree session): `agent_type` absent → BLOCKED by guard

## Actionable pattern

For batch plan promotions that can tolerate the Agent-tool overhead, prefer dispatching Orianna via the Agent tool from Evelynn rather than script-invoked worktree sessions. The former is trusted by the guard; the latter requires admin identity (`harukainguyen1411`) to bypass.

A follow-up ADR (Swain or Azir) is needed to address the script-path gap, either by propagating `agent_type` in the worktree invocation context or by adding a separate identity credential path for script spawns.
