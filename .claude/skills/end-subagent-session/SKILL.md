---
name: end-subagent-session
description: Close a Sonnet subagent session. Fast default — no writes, no commit, clean exit. Memory/learnings/handoff writes only when the session produced something genuinely durable. Subagents self-judge and invoke this themselves at session end. Required by CLAUDE.md rule 14 before closing any subagent session.
disable-model-invocation: false
allowed-tools: Bash Read Write Edit Glob Grep
---

# /end-subagent-session — Sonnet subagent close (lean)

You are closing a Sonnet subagent session. Subagents do NOT have their own `.jsonl` file (their conversation lives inside the parent's transcript as tool_use/tool_result blocks). There is nothing to clean.

**The default close path writes nothing.** Memory, learnings, and handoff notes are only written when the session produced something a future session will genuinely need. Mandatory logging on every close is a tax — skip it.

This skill does NOT apply to Evelynn or Sona (coordinators use their own close skills) or to Yuumi and Skarner (stateless, skip close entirely).

## Argument

`$ARGUMENTS` is the subagent name being closed. Required — no default. If empty, refuse with `end-subagent-session: agent name required`.

## Step 0 — Context probe

Same as `/end-session` step 0.

## Step 1 — Self-assessment (decision gate)

Ask yourself, honestly:

- Did this session produce a **durable fact** the future me (or another agent) will need? (new system constraint, infrastructure change, ownership shift, irreversible decision)
- Did I discover a **generalizable lesson** — a pattern, a gotcha, a mistake worth avoiding next time?
- Did I make a **plan decision** or resolve an open question that future work depends on?

**If all three answers are no → fast close.** Skip steps 2–5 entirely. Go to Step 6 (sentinel) and Step 7 (final report). Do not stage files. Do not commit.

**If any answer is yes → proceed to the relevant step(s) below.** Only write what's warranted. A session that produced one lesson but no durable fact writes learnings only. Be surgical.

## Step 2 — Handoff note (CONDITIONAL)

Only if the next session of this agent needs context you would otherwise lose.

Write `agents/<agent>/memory/last-session.md` with a terse 3-5 line handoff:
- Date (YYYY-MM-DD)
- What was accomplished this session (1-3 bullets)
- Open threads or blockers, if any

Stage the file. Do NOT invoke the `remember:remember` skill — sub-agents do not own their own remember state.

## Step 3 — Memory refresh (CONDITIONAL)

Only if the session produced a durable fact (system constraint, infra change, ownership shift).

Review `agents/<agent>/memory/<agent>.md`. Append a session row under `## Sessions` **only if** the session belongs in the history (not every routine execution). Add durable facts under `## Key Knowledge`. Prune oldest rows if over 30 lines. Stage.

Routine executions with no durable fact: do not touch this file.

## Step 4 — Learnings (CONDITIONAL)

Only if the session produced a **generalizable lesson** — something a future you or another agent would benefit from reading.

- Write `agents/<agent>/learnings/YYYY-MM-DD-<topic>.md` with the full lesson (3-10 lines typical).
- Append a one-line entry to `agents/<agent>/learnings/index.md`: `- YYYY-MM-DD-<topic>.md — <one-line summary> | last_used: YYYY-MM-DD`.
- Stage both files.

Bar is high. A one-line "completed X" is not a learning. If the session was routine execution with no surprises, skip.

## Step 5 — Commit + push (CONDITIONAL)

Only if steps 2-4 staged anything.

```
chore: <agent> subagent session closing — <one-line reason>
```

Push to main.

**If nothing is staged, skip this step entirely.** Do not create an empty commit.

## Step 6 — Sentinel (always)

Touch the sentinel file so the `SubagentStop` hook knows the closing protocol ran:

```bash
bash -c 'touch "/tmp/claude-subagent-${CLAUDE_SESSION_ID}-closed"'
```

This is the only unconditional step besides the final report.

## Step 7 — Final report

Same as `/end-session` step 11, minus the transcript and log_session lines. State plainly whether you wrote anything (and what), or closed clean.

## Refusal posture

Same as `/end-session`.

## Why the bar is high

Agent memory and learnings accumulate fast. Mandatory logging on every close produces noise that makes the signal harder to find. A sparse, curated memory is more useful than an exhaustive one. When in doubt, don't write.
