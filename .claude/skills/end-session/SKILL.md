---
name: end-session
description: Close a top-level Claude Code session end-to-end. Cleans the session jsonl into a verbatim markdown transcript, archives it under agents/<agent>/transcripts/, then walks the journal / handoff / memory / learnings / commit / log_session protocol. User-invocable only. Required by CLAUDE.md rule 14 before closing any top-level session.
disable-model-invocation: false
allowed-tools: Bash Read Write Edit Glob Grep
---

# /end-session — top-level session close

You are closing a top-level Claude Code session. This skill wraps the full close-session protocol into a deterministic checklist. Follow every step in order. Do not skip steps. Do not reorder.

## Argument

`$ARGUMENTS` is the agent name whose session is being closed. If empty, default to `evelynn` (the top-level coordinator is the most common invocation). If `$ARGUMENTS` is set to something other than a valid agent name (no matching `agents/<name>/` directory), refuse with `end-session: unknown agent <name>` and exit.

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

## Step 6 — Handoff note

Overwrite `agents/<agent>/memory/last-session.md` with a 5–10 line handoff. Rules:

- Date, what happened, open threads, any dangling commits or PRs, blockers for next session.
- Terse. No prose padding.

Use Write. Then stage:

```
git add -f agents/<agent>/memory/last-session.md
```

**Note:** `last-session.md` is gitignored globally (`.gitignore` entry `agents/*/memory/last-session.md`). The `-f` flag forces staging. This is the existing convention for Evelynn's handoff note; Phase 1 inherits it as-is.

## Step 7 — Memory refresh

Review `agents/<agent>/memory/<agent>.md`. If anything material changed this session (new working patterns, new known issues, sessions list), update it:

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

## Step 8a — Remember plugin handoff

Invoke the `remember:remember` skill via the Skill tool. This writes `.remember/remember.md` with a structured snapshot of session state. Run this step after all session artifacts (transcript, journal, handoff, memory, learnings) are written so the snapshot reflects the final state. The file must exist before the commit in Step 9 so it is included in the staged tree.

```
Skill: remember:remember
```

Stage the output file:

```
git add .remember/remember.md
```

If the `remember` plugin is not installed or the skill is unavailable, skip and note "remember step skipped — plugin not available" in the final report.

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

## Step 10 — log_session MCP call

If running on Mac and the `log_session` MCP tool is available, call it with:
- `agent`: `<agent>`
- `platform`: `cli`
- `model`: the current model name (best-effort — if unknown, use `claude-opus-4-6`)
- `notes`: `<one-line summary of the session, taken from the memory update>`

If running on Windows or the tool is unavailable, skip and note "log_session skipped — platform not supported" in the final report.

## Step 11 — Final report

Print a single-paragraph summary to the agent's output:

- Cleaned transcript path
- Commit hash
- Push status
- Journal / handoff / memory / learnings status (which were updated, which were skipped)
- log_session status
- Any warnings from the chain-walk or non-fatal errors along the way

Then exit. Do not close the session yourself — Duong or Evelynn explicitly ends the session after reviewing the report.

## Refusal posture

You are `disable-model-invocation: true`. The model cannot auto-fire you. Only explicit user invocation (`/end-session` in the CLI or Duong/Evelynn typing "run end-session") activates you. If any ambiguity about invocation, REFUSE with `end-session: requires explicit user invocation`.
