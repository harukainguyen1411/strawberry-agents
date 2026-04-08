---
name: end-subagent-session
description: Close a Sonnet subagent session. No transcript cleaning (subagents do not own a jsonl). Walks journal / handoff / memory / learnings / commit protocol only. User-invocable only. Required by CLAUDE.md rule 14 before closing any subagent session.
disable-model-invocation: true
allowed-tools: Bash Read Write Edit Glob Grep
---

# /end-subagent-session — Sonnet subagent close

You are closing a Sonnet subagent session. Subagents do NOT have their own `.jsonl` file (their conversation lives inside the parent's transcript as tool_use/tool_result blocks). There is nothing to clean. This skill walks the lightweight close protocol.

## Argument

`$ARGUMENTS` is the subagent name being closed. Required — no default. If empty, refuse with `end-subagent-session: agent name required`.

## Step 0 — Context probe

Same as `/end-session` step 0.

## Step 1 — Journal append

Same as `/end-session` step 5.

## Step 2 — Handoff note

Same as `/end-session` step 6.

## Step 3 — Memory refresh

Same as `/end-session` step 7.

## Step 4 — Learnings

Same as `/end-session` step 8.

## Step 5 — Commit + push

Same as `/end-session` step 9, except the commit message format is:

```
chore: <agent> subagent session closing — handoff, memory for YYYY-MM-DD session
```

## Step 6 — Final report

Same as `/end-session` step 11, minus the transcript and log_session lines.

## Refusal posture

Same as `/end-session`.
