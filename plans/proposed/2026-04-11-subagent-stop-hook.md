---
title: Enforce /end-subagent-session via SubagentStop hook
status: proposed
owner: pyke
date: 2026-04-11
---

# Enforce /end-subagent-session via SubagentStop hook

## Findings

Claude Code exposes a `SubagentStop` hook event (and `SubagentStart`). These fire when a subagent session ends or begins, respectively. This is exactly the harness-level intercept point needed.

The hook can use any of the standard hook types: `command`, `prompt`, or `agent`. The `agent` type is the most useful here — it can run with tool access and inject context back into the conversation.

## Recommended approach

Add a `SubagentStop` hook to `.claude/settings.json` that checks whether the `/end-subagent-session` skill was invoked during the subagent's session. Two options:

### Option A: Agent hook (recommended)

An `agent`-type hook on `SubagentStop` that inspects whether the closing protocol artifacts exist (updated `last-session.md`, memory refresh, commit). If they are missing, the hook returns a blocking `decision: "block"` with a `reason` telling the parent session that the subagent did not run its closing protocol.

Problem: the `SubagentStop` hook fires *after* the subagent has already stopped. It cannot force the subagent to run the skill retroactively. It can only alert the parent (Evelynn) that the protocol was skipped.

### Option B: Command hook with sentinel file (pragmatic)

1. `SubagentStart` hook: touch a sentinel file `/tmp/claude-subagent-<session_id>-started`.
2. The `/end-subagent-session` skill (already exists) touches `/tmp/claude-subagent-<session_id>-closed` as its final step.
3. `SubagentStop` hook: check if the `-closed` sentinel exists. If not, emit a `systemMessage` warning Evelynn that the subagent closed without running the end-session skill.

### Option C: Prompt hook (simplest, least reliable)

A `prompt`-type hook on `SubagentStop` that asks: "Did this subagent run /end-subagent-session? Check the conversation for evidence." This is cheap but depends on LLM judgment.

## Recommendation

**Option B** is the most reliable. It uses deterministic file checks, no LLM judgment, and surfaces the violation to Evelynn immediately so she can re-invoke the skill or flag it.

However, there is a fundamental limitation: `SubagentStop` fires *after* the subagent is gone. The hook cannot force the skill to run — it can only detect the miss and alert. True enforcement (blocking the subagent from closing until the skill runs) is not possible with current hook semantics.

## Implementation tasks

1. Add a one-line sentinel touch to the end of `/end-subagent-session` SKILL.md: `touch /tmp/claude-subagent-${CLAUDE_SESSION_ID}-closed` (or use a Bash call in the skill's commit step).

2. Add hooks to `.claude/settings.json`:

```json
{
  "SubagentStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "jq -r '.session_id' | { read -r sid; touch \"/tmp/claude-subagent-${sid}-started\"; }"
        }
      ]
    }
  ],
  "SubagentStop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "jq -r '.session_id' | { read -r sid; if [ ! -f \"/tmp/claude-subagent-${sid}-closed\" ]; then echo '{\"systemMessage\":\"WARNING: Subagent closed without running /end-subagent-session. Run the closing protocol manually.\"}'; fi; rm -f \"/tmp/claude-subagent-${sid}-started\" \"/tmp/claude-subagent-${sid}-closed\"; }"
        }
      ]
    }
  ]
}
```

3. Verify the stdin payload shape for `SubagentStart`/`SubagentStop` — the `session_id` field name is assumed from the general hook schema. May need testing to confirm the exact JSON keys available.

## Open questions for Duong

- The `SubagentStop` hook cannot *prevent* closing — only detect it after the fact. Is a warning to Evelynn sufficient, or does Duong want a harder gate? (A harder gate would require Anthropic to add a `PreSubagentStop` event or similar.)
- What is the exact stdin JSON shape for `SubagentStart`/`SubagentStop`? This needs empirical testing since it is not documented. The sentinel approach depends on a stable session identifier being available.
- Should the sentinel files use `$CLAUDE_SESSION_ID` env var (if available) or parse it from stdin JSON?
