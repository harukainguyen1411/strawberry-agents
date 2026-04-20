---
name: end-session
description: Close a top-level Claude Code session end-to-end. Cleans the session jsonl into a verbatim markdown transcript, archives it under agents/<agent>/transcripts/, then walks the journal / remember / memory / learnings / commit protocol. Required by CLAUDE.md rule 14 before closing any top-level session.
disable-model-invocation: true
allowed-tools: Bash Read Write Edit Glob Grep
---

# /end-session — top-level session close

You are closing a top-level Claude Code session. This skill wraps the full close-session protocol into a deterministic checklist. Follow every step in order. Do not skip steps. Do not reorder.

## Argument

`$ARGUMENTS` is the agent name whose session is being closed. If empty, refuse immediately with `end-session: agent name required — pass the agent name as an argument (e.g. /end-session evelynn)` and exit. If `$ARGUMENTS` is set to something other than a valid agent name (no matching `agents/<name>/` directory), refuse with `end-session: unknown agent <name>` and exit.

## Step 0 — Context probe

Run these Bash commands in a single call and keep the output in mind:

```
pwd
git status --short
git log -1 --oneline
date -u +%Y-%m-%dT%H:%M:%SZ
```

If the working tree has uncommitted changes unrelated to the session close (files outside `agents/<agent>/`, `scripts/`, `CLAUDE.md`, `.gitignore`), stop and report: `end-session: working tree dirty with unrelated files — commit or stash before closing`. Do not proceed.

## Step 1 — Discover source jsonl

Run the cleaner in dry-run mode (just discovery, no write) using the Bash tool:

```
python scripts/clean-jsonl.py --agent <agent> --session auto --out /tmp/end-session-probe.md
```

Note: for Phase 1, the cleaner does not have a separate dry-run flag. The `/tmp/` output path is a throwaway probe. After the probe, delete `/tmp/end-session-probe.md`.

Capture the stderr for any `CLEANER: chain ambiguous` warnings and relay them to the agent for confirmation before proceeding.

## Step 2 — Clean transcript

Run the cleaner for real:

```
python scripts/clean-jsonl.py --agent <agent> --session auto
```

The cleaner writes to the default path `agents/<agent>/transcripts/<YYYY-MM-DD>-<short-uuid>.md`.

- On exit code 0: record the output path from the cleaner's stdout.
- On exit code 1: report the error and stop. Do not proceed to any further step.
- On exit code 2: report the internal error and stop.
- On exit code 3: report the secret match verbatim, STOP IMMEDIATELY, do not stage any files, do not run the commit step. Escalate to Duong via the final report.

## Step 3 — Stage the transcript

```
git add agents/<agent>/transcripts/<YYYY-MM-DD>-<short-uuid>.md
```

Verify the file is staged with `git status --short`.

## Step 4 — (reserved for condenser, no-op in Phase 1)

Log `end-session: condenser step skipped — Phase 2 will wire Syndra's component A here` and continue.

## Step 5 — Journal append

Prompt the invoking agent (you, running this skill) to append their first-person reflection for this session to `agents/<agent>/journal/cli-<YYYY-MM-DD>.md`. Rules:

- Append only. Do NOT overwrite existing content.
- First-person voice. Not a transcript copy.
- 10–30 lines typical. No hard cap.

Use the Write tool if the file does not exist, Edit (append) if it does. After writing, stage the file:

```
git add agents/<agent>/journal/cli-<YYYY-MM-DD>.md
```

## Step 6 — Remember handoff

**If agent == evelynn:** Skip the `remember:remember` plugin entirely (it has a single-file race surface unsafe under concurrent close — see D6 in `plans/approved/2026-04-18-evelynn-memory-sharding.md`). Instead, write a new shard at `agents/evelynn/memory/last-sessions/<short-uuid>.md` where `<short-uuid>` is the UUID from Step 2's transcript path. Content: a structured 5–10 line handoff — date, session number, what happened, open threads, dangling commits or PRs, blockers. Stage:

```
git add agents/evelynn/memory/last-sessions/<short-uuid>.md
```

Note "remember:remember bypassed for evelynn — shard written to last-sessions/<short-uuid>.md" in the final report.

**If agent != evelynn:** Invoke the `remember:remember` skill via the Skill tool. This is the primary handoff mechanism — it writes `.remember/remember.md` with a structured snapshot of what is done, what is next, and any non-obvious context. The Remember plugin's `SessionStart` hook loads this automatically at the start of the next session.

```
Skill: remember:remember
```

Stage the output file:

```
git add .remember/remember.md
```

If the `remember` plugin is not installed or the skill is unavailable, fall back to writing `agents/<agent>/memory/last-session.md` manually with a 5–10 line terse handoff (date, what happened, open threads, dangling commits or PRs, blockers). Stage with `git add -f agents/<agent>/memory/last-session.md`. Note "remember step skipped — plugin not available, used last-session.md fallback" in the final report.

## Step 7 — Memory refresh

**If agent == evelynn:** Do NOT touch `agents/evelynn/memory/evelynn.md`. Instead, write a new shard at `agents/evelynn/memory/sessions/<short-uuid>.md` (same UUID from Step 2) containing:
- A `## Session YYYY-MM-DD (SN, <mode>)` heading.
- One-line summary of the session.
- Any delta notes to Key Context or Working Patterns that should be folded in at next consolidation.

Stage the shard:

```
git add agents/evelynn/memory/sessions/<short-uuid>.md
```

Note "evelynn memory shard written to sessions/<short-uuid>.md — consolidation will fold into evelynn.md at next boot" in the final report.

**If agent != evelynn:** Review `agents/<agent>/memory/<agent>.md`. If anything material changed this session (new working patterns, new known issues, sessions list), update it:

- Append a new session row to the `## Sessions` list with the format `- YYYY-MM-DD (SN, <mode>): <one-line summary>`.
- Prune stale entries if the file exceeds 50 lines. Remove the oldest session rows first.
- Update `## Key context` or `## Working patterns` only if the change is durable.

If nothing material changed, skip the update but still state "no memory changes this session" in the final report. Stage if modified:

```
git add agents/<agent>/memory/<agent>.md
```

## Step 8 — Learnings

If this session produced a generalizable lesson (something a future instance of this agent or a sibling agent would benefit from), write it to `agents/<agent>/learnings/<YYYY-MM-DD>-<topic>.md` and add a one-line reference to `agents/<agent>/learnings/index.md`.

If no learning, skip and state "no learnings this session" in the final report.

Stage any new learning files:

```
git add agents/<agent>/learnings/
```

## Step 9 — Commit + push

Build the commit message. Format:

```
chore: <agent> session closing — transcript, handoff, memory, learnings for YYYY-MM-DD <platform> session
```

Use `cli` as the platform for Claude Code sessions. Use HEREDOC form:

```
git commit -m "$(cat <<'EOF'
chore: <agent> session closing — transcript, handoff, memory, learnings for YYYY-MM-DD <platform> session

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Then push:

```
git push
```

**If the pre-push hook rejects the commit** (wrong prefix, gitleaks hit, anything): STOP. Do not retry. Do not rewrite the commit. Report the error verbatim in the final report and exit with `end-session: commit rejected — manual intervention required`.

**If the push fails because main moved forward**: pull with merge (never rebase per CLAUDE.md git rules), then re-push. One retry only. If the second push fails, stop and report.

## Step 10 — Final report

Print a single-paragraph summary to the agent's output:

- Cleaned transcript path
- Commit hash
- Push status
- Journal / remember handoff / memory / learnings status (which were updated, which were skipped)
- Any warnings from the chain-walk or non-fatal errors along the way

Then exit. Do not close the session yourself — Duong or Evelynn explicitly ends the session after reviewing the report.

## Refusal posture

You are `disable-model-invocation: true`. This skill MUST only be triggered explicitly by Duong or Evelynn typing `/end-session`. It cannot auto-fire on model judgment. If Duong's intent is ambiguous, ask before firing.
