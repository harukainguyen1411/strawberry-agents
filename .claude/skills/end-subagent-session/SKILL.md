---
name: end-subagent-session
description: Close a Sonnet subagent session. No transcript cleaning (subagents do not own a jsonl). Walks journal / handoff / memory / learnings / commit protocol only. Subagents invoke this themselves at session end. Required by CLAUDE.md rule 14 before closing any subagent session.
disable-model-invocation: false
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

Write `agents/<agent>/memory/last-session.md` with a terse 3-5 line handoff:
- Date (YYYY-MM-DD)
- What was accomplished this session (1-3 bullets)
- Open threads or blockers, if any

Stage the file. Do NOT invoke the `remember:remember` skill — sub-agents do not own their own remember state.

## Step 3 — Memory refresh

Review `agents/<agent>/memory/<agent>.md`.

- Append a session row under `## Sessions`: `- YYYY-MM-DD: <one-line summary of what was accomplished>`.
- If the agent learned a new working pattern or discovered a system constraint during this session, add it under `## Key Knowledge`.
- Prune if the file exceeds 30 lines — sub-agents have a tighter budget than Evelynn's 50 lines. Remove the oldest session rows first.
- Stage the file.

## Step 4 — Learnings

If this session produced a generalizable lesson (a reusable pattern, a system constraint discovered, a mistake worth avoiding):

- Write `agents/<agent>/learnings/YYYY-MM-DD-<topic>.md` with the full lesson (3-10 lines typical).
- Append a one-line entry to `agents/<agent>/learnings/index.md`: `- YYYY-MM-DD-<topic>.md — <one-line summary> | last_used: YYYY-MM-DD`.
- Stage both files.

If no generalizable lesson emerged, skip this step.

## Step 5 — Commit + push

Stage all modified files and commit:

```
chore: <agent> subagent session closing — handoff, memory for YYYY-MM-DD session
```

Push to main.

Then touch the sentinel file so the `SubagentStop` hook knows the closing protocol ran:

```bash
bash -c 'touch "/tmp/claude-subagent-${CLAUDE_SESSION_ID}-closed"'
```

## Step 6 — Final report

Same as `/end-session` step 11, minus the transcript and log_session lines.

## Refusal posture

Same as `/end-session`.
