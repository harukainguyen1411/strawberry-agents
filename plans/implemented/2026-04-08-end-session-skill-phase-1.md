---
title: /end-session Skill — Phase 1 Execution Spec
status: in-progress
owner: bard
detailed_owner: bard
created: 2026-04-08
supersedes_rough: plans/proposed/2026-04-08-end-session-skill.md
---

# /end-session Skill — Phase 1 Execution Spec

> Detailed, Sonnet-executable spec for Phase 1 of the `/end-session` skill. Fold-in of Duong's four confirmed decisions (two-skill split, supersede v1 /close-session, commit cleaned transcripts, ship independent of Syndra's condenser) and three amendments (universal scope + mandatory rule, .gitignore fix, pre-commit guard allowlist verification). The rough plan at `plans/proposed/2026-04-08-end-session-skill.md` is superseded by this file and stays in `proposed/` for record-keeping only.
>
> **Rule 7 still applies.** Bard wrote this plan and must not self-implement. Evelynn delegates execution after Duong confirms readiness.
>
> **Privacy notice for the commit that lands this plan.** Phase 1 commits cleaned conversation transcripts into git. Every cleaned transcript contains verbatim user prompts and assistant prose from a session. Gitleaks pre-commit + a cleaner-internal secret denylist are the two guardrails; the cleaner MUST fail loudly (nonzero exit, skill aborts) when either fires. Duong accepted the privacy tradeoff explicitly on 2026-04-08.

## Scope summary

Phase 1 ships:

1. `scripts/clean-jsonl.py` — deterministic Python cleaner reading raw session `.jsonl` and writing cleaned Markdown.
2. `.claude/skills/end-session/SKILL.md` — the orchestration skill (clean → archive → journal → handoff → memory → learnings → commit → log_session → final report).
3. `.claude/skills/end-subagent-session/SKILL.md` — the Sonnet-subagent variant (no jsonl cleaner, no archive, steps 6–10 only). **Included in Phase 1** per Bard's judgment — the skill is ~40 lines and shipping the split in one batch avoids a second planning cycle.
4. New CLAUDE.md rule 14 — mandatory invocation of `/end-session` (or `/end-subagent-session`) before closing any session.
5. `.gitignore` update to negate `agents/*/transcripts/*.md` so cleaned markdown transcripts are tracked.
6. `scripts/pre-commit-secrets-guard.sh` verification (fix already landed in commit `c633f4a`; Phase 1 re-checks and does NOT re-add).
7. `agents/memory/agent-network.md` Session Closing Protocol rewrite to point at the skill.
8. Creation of `agents/<agent>/transcripts/` directories for every roster agent (empty placeholder via `.gitkeep`).

Phase 1 does NOT ship:

- The condenser (Syndra's continuity plan Component A). The skill reserves Step 5 as a no-op with a log line.
- A hard pre-exit enforcement hook. Phase 2 territory — spec'd in Section 7 of this plan but not implemented.
- Any modification to the approved skills-integration plan file. The v1 `/close-session` skill from that plan is superseded by convention (nobody builds it) and by the new CLAUDE.md rule 14 pointing at `/end-session`. No files to delete because the v1 skill was never implemented.
- Subagent-interior transcript preservation. Deferred to Phase 3.

## Section 1 — File manifest

All paths are relative to the repo root `C:/Users/AD/Duong/strawberry/`.

### CREATE

| # | Path | Description |
|---|---|---|
| C1 | `scripts/clean-jsonl.py` | Python stdlib-only cleaner. Reads raw session `.jsonl`(s), writes cleaned Markdown. Signature per Section 2. |
| C2 | `.claude/skills/end-session/SKILL.md` | Full top-level close skill. Content per Section 3.1. |
| C3 | `.claude/skills/end-subagent-session/SKILL.md` | Lightweight Sonnet-subagent close skill. Content per Section 3.2. |
| C4 | `agents/bard/transcripts/.gitkeep` | Empty placeholder so the directory exists. |
| C5 | `agents/caitlyn/transcripts/.gitkeep` | Same. |
| C6 | `agents/evelynn/transcripts/.gitkeep` | Same. (Directory already exists with today's cleaned transcript; `.gitkeep` is still added for uniformity.) |
| C7 | `agents/fiora/transcripts/.gitkeep` | Same. |
| C8 | `agents/katarina/transcripts/.gitkeep` | Same. |
| C9 | `agents/lissandra/transcripts/.gitkeep` | Same. |
| C10 | `agents/neeko/transcripts/.gitkeep` | Same. |
| C11 | `agents/ornn/transcripts/.gitkeep` | Same. |
| C12 | `agents/poppy/transcripts/.gitkeep` | Same. |
| C13 | `agents/pyke/transcripts/.gitkeep` | Same. |
| C14 | `agents/reksai/transcripts/.gitkeep` | Same. |
| C15 | `agents/swain/transcripts/.gitkeep` | Same. |
| C16 | `agents/syndra/transcripts/.gitkeep` | Same. |
| C17 | `agents/yuumi/transcripts/.gitkeep` | Same. |
| C18 | `agents/zoe/transcripts/.gitkeep` | Same. |

**Note on C4–C18:** the set of agents is taken from `agents/memory/agent-network.md` Agent Roster table plus `agents/bard/` (authoring), plus `agents/yuumi/` and `agents/poppy/` (Sonnet/minion tier). Any agent folder under `agents/` that has a `memory/` subdir gets a `transcripts/` subdir. If Katarina finds an agent folder I missed while walking `agents/`, she adds one `.gitkeep` for it following the same pattern. Exclude: `agents/conversations/`, `agents/delegations/`, `agents/health/`, `agents/inbox/`, `agents/journal/`, `agents/learnings/`, `agents/memory/`, `agents/wip/` — those are shared infra, not agents.

### MODIFY

| # | Path | Change |
|---|---|---|
| M1 | `CLAUDE.md` | Add new rule 14 after existing rule 13. Exact text in Section 4 Step 8. |
| M2 | `.gitignore` | Under the existing `# Transcripts (large, auto-generated)` block, negate cleaned markdown transcripts. Exact diff in Section 4 Step 9. |
| M3 | `scripts/pre-commit-secrets-guard.sh` | **Verify only.** Katarina's S23 fix (commit `c633f4a`) already added `agents/.*/transcripts/` to `allowed_decrypt_pattern` at line 72. Section 4 Step 10 re-confirms this with a grep. No edit expected. |
| M4 | `agents/memory/agent-network.md` | Rewrite the `## Session Closing Protocol` section to point at `/end-session` and `/end-subagent-session` as the mechanical wrapper. Exact replacement text in Section 4 Step 11. |

### DELETE

Nothing. The v1 `/close-session` skill from the approved skills-integration plan was never built (`ls .claude/skills/` confirms the directory does not exist). There is no file to remove. The supersession is implicit: Phase 1 ships `/end-session` and `/end-subagent-session`, and rule 14 + Section 5 of this plan explicitly mark `/close-session` as abandoned. The skills-integration plan itself stays as-is — Bard will not edit an approved plan from this detailed spec.

### This plan file itself

`plans/ready/2026-04-08-end-session-skill-phase-1.md` is the plan you are reading. It is committed by Bard (the author of this plan) before Katarina picks up execution. Katarina does not create it.

## Section 2 — The jsonl cleaner (scripts/clean-jsonl.py)

### 2.1 Purpose

Read one or more Claude Code session `.jsonl` files and emit a single Markdown file containing only the verbatim user prompts and assistant prose, stripped of tool calls, tool results, system reminders, harness-injected context blocks, and extended thinking.

### 2.2 Input discovery

The cleaner runs from the repo root. It accepts the following arguments:

```
python scripts/clean-jsonl.py \
    --agent <name> \
    [--session <uuid|auto>] \
    [--out <path>] \
    [--project-dir <path>]
```

- `--agent` (required): the agent name whose session is being closed. Used for the assistant-side speaker label in the output and for the default `--out` path. Accept any string of `[a-z][a-z0-9-]*`; do not validate against the roster (keeps the cleaner decoupled from roster changes).
- `--session` (default `auto`): either a full session UUID (e.g. `08881199-cd7d-438b-9b0e-ed39eeb16280`), a short prefix (first 8 hex chars), or the literal string `auto`. `auto` triggers session-chain-by-mtime discovery (see 2.3).
- `--out` (default `agents/<agent>/transcripts/<YYYY-MM-DD>-<slug>.md` where `<YYYY-MM-DD>` is derived from the earliest user message timestamp in the cleaned output and `<slug>` is the short UUID of the most-recent jsonl in the chain): where to write the cleaned Markdown.
- `--project-dir` (default `C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/` on Windows, `$HOME/.claude/projects/-Users-$(whoami)-Duong-strawberry/` on macOS, `$HOME/.claude/projects/-home-$(whoami)-Duong-strawberry/` on Linux): the directory to scan for session `.jsonl` files. **Katarina: hardcode the Windows path as the default and accept the override from the skill. Do not try to derive the mac/linux paths for Phase 1 — the skill is currently windows-only in practice.**

Exit codes:
- `0` on success.
- `1` on any user error (bad args, missing files, empty session).
- `2` on internal error (encoding, unexpected record shape).
- `3` if the cleaner's secret denylist fires on any written line (see 2.9).

### 2.3 Session-chain-by-mtime discovery (Katarina's proven S23 approach)

When `--session auto`, the cleaner:

1. Lists all `*.jsonl` files directly in `<project-dir>` (not nested). Use `os.scandir`, filter by `name.endswith('.jsonl')` and `is_file()`. Ignore any nested subdirectories in `<project-dir>` (the `08881199-.../` style dirs are unrelated harness artifacts — S23 confirmed this).
2. Sorts by `st_mtime` descending.
3. Picks the most-recent jsonl as the "head" of the session chain.
4. Walks backwards to find chained files: a jsonl is part of the same session chain if its last record has a continuation marker OR if it is directly adjacent in mtime (within a configurable gap — default 30 minutes, see 2.4) AND the final assistant/user pair in the older file matches the opening user/assistant pair of the newer file by content hash (not UUID — S23 found the UUIDs don't chain).
5. Returns the ordered list of `.jsonl` files, oldest first.

If the chain-walk is ambiguous (multiple candidates at the same mtime, or a gap straddles the 30-minute threshold), the cleaner prints the discovered chain to stderr, prefixed with `CLEANER: chain ambiguous — using`, and proceeds with its best guess. The skill body (Section 3.1) surfaces this warning to the agent.

When `--session <uuid-or-prefix>`, the cleaner starts the walk from that specific file instead of the mtime head.

**Katarina's S23 actually worked** by manually enumerating the four files in mtime order. Her approach is the reference implementation. If the auto-chain algorithm drifts from her manual selection for today's session (`70b0c1f3` → `771bc0fd` → `8a29daf0` → `08881199`), the algorithm is wrong — fix the algorithm, not the data.

### 2.4 Chain gap threshold

30 minutes between consecutive jsonl mtimes is treated as "same session continued." Rationale: Claude Code rotates jsonl files on certain events (tool-call-heavy turns, context pressure), and a 30-minute idle gap inside one work session is normal. A gap larger than 30 minutes is treated as a session boundary and the chain walk stops.

Katarina: expose this as a module-level constant `CHAIN_GAP_SECONDS = 30 * 60` at the top of the script. No CLI flag for Phase 1.

### 2.5 JSONL record schema (what the cleaner reads)

Each line of a `.jsonl` is a JSON object. The cleaner cares about these top-level keys:

- `type` — one of `user`, `assistant`, `summary`, `system` (and others the cleaner ignores).
- `message` — the Claude API message object with `role` and `content`.
- `isSidechain` — boolean; if `true`, this record is a subagent chain and the cleaner drops it entirely (S23 rule).
- `uuid` / `parentUuid` — record identifiers, used for de-dup across chained files (not ordering).
- `timestamp` — ISO 8601 string, used for section headers.

### 2.6 Filtering rules (copy-paste ready, Katarina: follow exactly)

For each line:

1. Parse as JSON. On parse failure, skip the line and log `CLEANER: skipped malformed line <N> in <file>` to stderr. Do not abort.
2. If `record.get('isSidechain') is True`, skip.
3. Switch on `record.get('type')`:
   - `user`:
     - Extract `message.content`. It can be either a string (old format) or a list of content blocks.
     - If it is a string: apply the "stripping" rules in 2.7 to get the user text. If the result is non-empty after stripping, emit a user-side section.
     - If it is a list: iterate blocks. For each block of `type == 'text'`, apply the stripping rules to its `text` field. Ignore blocks of `type == 'tool_result'` (those are tool returns the harness attaches to user-role records). Ignore any other block type. Concatenate surviving text in order with `\n\n` between blocks. If the result is non-empty, emit a user-side section.
   - `assistant`:
     - Extract `message.content` (always a list for the assistant).
     - Iterate blocks. For each block of `type == 'text'`, collect `block.text`. Ignore `type == 'tool_use'`, `type == 'thinking'`, `type == 'tool_result'`, and any other block type entirely.
     - Join collected texts with `\n\n` (no tool-use separator — concatenation reads as continuous prose).
     - If the joined result is non-empty after whitespace trim, emit an assistant-side section.
   - Anything else: skip silently.
4. Maintain an in-memory set of `(record_uuid, content_hash)` tuples. If a record is a repeat across chained files (same uuid OR same content hash on consecutive same-role sections), skip the duplicate.
5. Maintain a running timestamp cursor. Each emitted section header includes the record's ISO timestamp.

### 2.7 Stripping rules for user text (exact denylist)

The harness injects synthetic content into user messages. The cleaner strips these wrappers. Input text goes through these steps in order:

1. **System reminder blocks.** Remove every substring matching the regex (DOTALL mode):
   ```
   <system-reminder>.*?</system-reminder>
   ```
2. **Local command stdout/stderr wrappers.**
   ```
   <local-command-stdout>.*?</local-command-stdout>
   <local-command-stderr>.*?</local-command-stderr>
   ```
3. **Command name / command message wrappers.**
   ```
   <command-name>.*?</command-name>
   <command-message>.*?</command-message>
   <command-args>.*?</command-args>
   ```
4. **Local command caveat.** Remove every substring matching:
   ```
   Caveat: The messages below were generated by the user while running local commands.*?(?=\n\n|\Z)
   ```
   (DOTALL, non-greedy, bounded by double-newline or end-of-string.)
5. **Task notification wrappers.**
   ```
   <task-notification>.*?</task-notification>
   ```
6. **Harness-injected envelope blocks.** If the text, after the above stripping, consists ONLY of a sequence of `# <header>` / content blocks matching the denylist below (no actual user prose), replace the entire text with empty string. Denylist headers:
   - `# claudeMd`
   - `# currentDate`
   - `# gitStatus`
   - `# Memory Index`
   - `<env>...</env>` block
   - `<context>...</context>` block
   - The leading `Contents of` line immediately following `# claudeMd`
7. **Mixed envelopes + real prose.** If a message contains BOTH envelope blocks AND real prose, strip ONLY the envelope blocks (remove from opening `# <header>` line through the next `# ` header or end of message, whichever comes first) and keep the prose.
8. **Whitespace normalization.** After all stripping, collapse runs of 3+ consecutive newlines into 2, then trim leading/trailing whitespace.
9. **Empty check.** If the result is empty or whitespace-only, this message does NOT emit a section.

**Edge case from S23 that the denylist must handle:** user messages whose ONLY content is a system reminder wrapping `Today's date is X` (the harness sometimes injects date stamps mid-conversation). After stripping the reminder, result is empty, section is dropped. Correct behavior.

### 2.8 Stripping rules for assistant text

Assistant text blocks are Duong's model speaking. Minimal stripping:

1. **No system-reminder stripping** — the assistant does not receive system reminders in its `text` blocks.
2. **Strip trailing tool-call scaffolding phrases.** Some assistant text blocks end with phrases like `Let me check this.` immediately before a tool_use block. These are legitimate assistant prose, KEEP THEM. Do not strip. The tool_use block itself is already dropped by the content-block filter.
3. **Whitespace normalization.** Same as user: collapse 3+ newlines to 2, trim ends.
4. **Empty check.** Drop empty results.

### 2.9 Secret denylist (belt and suspenders)

Before writing the output file, the cleaner scans every line about to be written for these patterns:

```
age1[ac-hj-np-z02-9]{58}        # age recipient (public key is fine, private is not — but both trip)
AGE-SECRET-KEY-1[A-Z0-9]{58}    # age private key (the one we care about)
sk-[A-Za-z0-9_-]{20,}           # Anthropic / OpenAI API keys
ghp_[A-Za-z0-9]{30,}            # GitHub PAT
gho_[A-Za-z0-9]{30,}            # GitHub OAuth
xoxb-[A-Za-z0-9-]{20,}          # Slack bot
xoxp-[A-Za-z0-9-]{20,}          # Slack user
AKIA[0-9A-Z]{16}                # AWS access key
-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----
```

**On match: hard-fail.** Print `CLEANER: secret pattern matched — refusing to write <path>. pattern=<name>. line=<N>`. Exit code 3. The skill body (Section 3.1) interprets exit 3 as a fatal abort and does NOT proceed to the commit step.

**Not a redaction pass.** We do NOT rewrite matched lines to `[redacted]` — the whole point is to refuse silently-poisoned transcripts. Fail loud.

Rationale per Duong: "gitleaks finds anything matching a secret pattern (fail loud, not silent skip)."

### 2.10 Output format

One Markdown file. Header block, then alternating sections.

```
# Session <short-uuid> — <YYYY-MM-DD> — <agent-name>

> Cleaned transcript. Tool calls, tool results, system reminders, extended thinking, and harness-injected context blocks have been stripped. Only user prompts and assistant prose remain.
>
> Source files:
> - <absolute path to jsonl #1>
> - <absolute path to jsonl #2>
> ...
>
> Cleaned at: <ISO timestamp of cleaner invocation>
> Message count: <user N, assistant M>
> Chain-walk: <auto|explicit> — <chain-resolution-note-if-any>

---

## Duong — <ISO timestamp of first user message>

<verbatim cleaned user text>

## <Agent-Name-TitleCase> — <ISO timestamp of first assistant message>

<verbatim cleaned assistant text>

## Duong — <ISO timestamp>

...
```

**Speaker header rules:**
- User side is always `Duong`.
- Assistant side is `<agent-name>` with the first letter uppercased (`evelynn` → `Evelynn`, `bard` → `Bard`). Do not title-case multi-word names — none currently exist.
- Timestamp format: `YYYY-MM-DDTHH:MM:SSZ` (UTC, from the record's `timestamp` field, second precision).
- If a record has no timestamp, use `<unknown>`.

### 2.11 Multi-jsonl concatenation

When the chain walk returns multiple files, the cleaner streams them in order. Records are emitted in file order, not timestamp order (timestamps can drift across file boundaries during harness rotation). De-duplication (2.6 step 4) catches any overlap at chain boundaries.

### 2.12 Error handling

| Condition | Behavior |
|---|---|
| `--project-dir` does not exist | Exit 1 with `CLEANER: project dir not found: <path>` |
| No `.jsonl` files in project dir | Exit 1 with `CLEANER: no session jsonl files in <path>` |
| Explicit `--session` UUID not found | Exit 1 with `CLEANER: session <uuid> not found in <path>` |
| Session file is 0 bytes | Exit 1 with `CLEANER: session <uuid> is empty` |
| Session has records but all are filtered out (empty cleaned output) | Write a stub Markdown file with the header and a `> (no surviving user or assistant prose in this session)` note. Exit 0. |
| UnicodeDecodeError on a line | Skip the line, log to stderr, continue. If more than 10% of lines fail, abort with exit 2. |
| Unknown content block type | Skip the block, do NOT abort. Log at most one warning per block type per run. |
| Secret denylist match | Exit 3. See 2.9. |
| Output path's parent directory does not exist | `mkdir -p` the parent. If that fails, exit 1. |

### 2.13 Dependencies

**Python stdlib only.** No pip installs. Imports permitted:
```python
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import sys
```

Python 3.11+ assumed (matches the rest of the repo).

### 2.14 Line count budget

The cleaner should fit in ~300–400 lines of Python. If it grows past 500 lines, Katarina should stop and escalate to Evelynn — that's a signal the spec is under-specified or the implementation is overengineered.

## Section 3 — Skill file contents

### 3.1 .claude/skills/end-session/SKILL.md

**Frontmatter:**

```yaml
---
name: end-session
description: Close a top-level Claude Code session end-to-end. Cleans the session jsonl into a verbatim markdown transcript, archives it under agents/<agent>/transcripts/, then walks the journal / handoff / memory / learnings / commit / log_session protocol. User-invocable only. Required by CLAUDE.md rule 14 before closing any top-level session.
disable-model-invocation: true
allowed-tools: Bash Read Write Edit Glob Grep
---
```

**Body** (Katarina writes this verbatim; the `$ARGUMENTS` placeholder is the optional agent name):

```markdown
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
```

### 3.2 .claude/skills/end-subagent-session/SKILL.md

**Frontmatter:**

```yaml
---
name: end-subagent-session
description: Close a Sonnet subagent session. No transcript cleaning (subagents do not own a jsonl). Walks journal / handoff / memory / learnings / commit protocol only. User-invocable only. Required by CLAUDE.md rule 14 before closing any subagent session.
disable-model-invocation: true
allowed-tools: Bash Read Write Edit Glob Grep
---
```

**Body:**

```markdown
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
```

## Section 4 — Step-by-step execution order for Katarina

**Prerequisite.** Before touching anything, Katarina reads this entire plan file. Every "exact text" block below is copy-paste ready.

### Step 1 — Verify the pre-commit guard allowlist (no edit)

Run:
```
grep -n 'agents/\.\*/transcripts/' scripts/pre-commit-secrets-guard.sh
```

Expected: exactly one match at line 72, inside the `allowed_decrypt_pattern` regex. If the match is present, **do not modify the file**. If the match is absent, STOP and escalate to Evelynn — Katarina's S23 commit `c633f4a` should have landed this fix. Do NOT re-add it speculatively; verify the commit history first.

### Step 2 — Create `.claude/skills/` directory

```
mkdir -p .claude/skills/end-session .claude/skills/end-subagent-session
```

### Step 3 — Author `scripts/clean-jsonl.py`

Implement per Section 2 of this plan. Keep the file self-contained, stdlib-only. Target ~300 lines.

After writing, syntax-check:
```
python -m py_compile scripts/clean-jsonl.py
```

Expected: exit 0, no output.

### Step 4 — Smoke-test the cleaner against today's already-archived session

The existing transcript at `agents/evelynn/transcripts/2026-04-08-cafe-to-home-session.md` (committed in S23, commit `0436882`) is the reference output. Run:

```
python scripts/clean-jsonl.py --agent evelynn --session auto --out /tmp/end-session-smoke.md
```

(If `/tmp` is not writable on Windows — it should be under Git Bash — use `./wip/end-session-smoke.md` instead.)

Compare the smoke output to the reference:

```
diff -u agents/evelynn/transcripts/2026-04-08-cafe-to-home-session.md /tmp/end-session-smoke.md | head -200
```

**Expected**: the smoke output should be either identical to or a strict superset of the reference (the reference was generated by Katarina's manual one-shot extractor in S23 which used the same rules the cleaner implements). Acceptable divergences:

- Differences in the header block (timestamps, chain-walk note) — these are expected because the cleaner has a richer header.
- Small whitespace differences inside assistant blocks — acceptable if the prose matches word-for-word.

**Unacceptable divergences** that require fixing the cleaner before proceeding:

- Any surviving `tool_use`, `tool_result`, or `thinking` content.
- Any surviving `<system-reminder>`, `<local-command-*>`, `<command-*>`, or `<task-notification>` wrapper.
- Any surviving `# claudeMd` / `# currentDate` / `# gitStatus` envelope.
- Section counts off by more than 5% from the reference (309 turns in the reference — cleaner should produce 294–324 turns).

After the smoke test passes, delete the probe output:
```
rm /tmp/end-session-smoke.md
```

### Step 5 — Author `.claude/skills/end-session/SKILL.md`

Copy the frontmatter and body from Section 3.1 of this plan verbatim. No modifications.

### Step 6 — Author `.claude/skills/end-subagent-session/SKILL.md`

Copy the frontmatter and body from Section 3.2 verbatim.

### Step 7 — Create transcripts directories with .gitkeep

For each agent in the manifest (C4–C18):

```
mkdir -p agents/<name>/transcripts
touch agents/<name>/transcripts/.gitkeep
```

Then verify the complete list with:
```
ls -d agents/*/transcripts/
```

Expected: one entry per agent in the manifest, all containing `.gitkeep`.

### Step 8 — Add CLAUDE.md rule 14

Read `CLAUDE.md` first. Locate rule 13 (`**Never end your session after completing a task**`). Insert the new rule immediately after rule 13, before the `## Scope` heading.

**Exact text to add (Katarina copy-paste):**

```
14. **Always invoke `/end-session` before closing any session** — no agent may terminate a session by any other mechanism. Top-level Claude Code sessions use `/end-session`; Sonnet subagent sessions use `/end-subagent-session`. These skills produce the cleaned-transcript archive (top-level only), handoff note, memory refresh, learnings, and commit. Closing without running the appropriate skill is a protocol violation. The skills are `disable-model-invocation: true` — Duong or Evelynn must explicitly trigger them.
```

Do NOT renumber any existing rules. Rule 14 is additive.

Verify with:
```
grep -n '^14\.' CLAUDE.md
```

Expected: exactly one match.

### Step 9 — .gitignore update

Read `.gitignore`. Find the block:

```
# Transcripts (large, auto-generated)
transcripts/
```

Replace it with:

```
# Transcripts (large, auto-generated at project root — NOT agent transcripts)
transcripts/

# Agent cleaned-transcript archives ARE committed (see /end-session skill)
!agents/*/transcripts/
!agents/*/transcripts/*.md
!agents/*/transcripts/.gitkeep
```

Verify the negation works with:
```
git check-ignore -v agents/evelynn/transcripts/2026-04-08-cafe-to-home-session.md
```

Expected: exit 1 (the file is NOT ignored). If `git check-ignore` reports the file is ignored by the `transcripts/` rule, the negation order is wrong — the `!` lines must come AFTER the base `transcripts/` rule.

Also verify a test path at the project root is still ignored:
```
git check-ignore -v transcripts/some-test.md
```

Expected: exit 0, matched by `transcripts/`.

### Step 10 — Rewrite agent-network.md Session Closing Protocol

Read `agents/memory/agent-network.md`. Locate the `## Session Closing Protocol` heading. Replace the entire section (from `## Session Closing Protocol` through the end of the `Steps 1-4 mandatory. Step 5 only when applicable.` line — the section ends at the `## Restricted Tools` heading) with:

**Exact replacement text:**

```
## Session Closing Protocol

**When to close:** Only when Duong or Evelynn explicitly says to end your session (e.g., "end session", "shut down", "close"). Completing a task is NOT a trigger to close. After task completion, stay open and wait.

**Mechanical wrapper (mandatory, CLAUDE.md rule 14):**

- Top-level Claude Code sessions: invoke `/end-session [agent-name]`.
- Sonnet subagent sessions: invoke `/end-subagent-session <agent-name>`.

The skill walks the full close protocol deterministically (cleaned-transcript archive for top-level sessions, journal, handoff, memory, learnings, commit, log_session). Do not execute the protocol steps manually — the skill is the source of truth and guarantees step ordering, commit format, and secret-denylist checks.

**What the skill does under the hood** (for reference; you do not execute these steps yourself):

1. **Clean transcript** (top-level only) — `scripts/clean-jsonl.py` produces `agents/<agent>/transcripts/<date>-<uuid>.md`.
2. **Journal append** — your first-person reflection goes to `journal/cli-YYYY-MM-DD.md`.
3. **Handoff note** — `memory/last-session.md` (5–10 lines, force-staged because gitignored).
4. **Memory refresh** — `memory/<name>.md` updated if material changed, pruned to under 50 lines.
5. **Learnings** — optional, written to `learnings/<date>-<topic>.md` and indexed.
6. **Commit + push** — single commit with `chore:` prefix, single push.
7. **log_session** — MCP call on Mac, skipped on Windows.

**If the skill refuses or aborts** (dirty working tree, secret denylist hit, commit rejected, etc.): stop, do not bypass the skill, escalate to Evelynn via inbox or direct report. Closing a session by any mechanism other than the skill is a rule 14 violation.
```

### Step 11 — Stage everything + commit

Stage the full set:

```
git add \
    scripts/clean-jsonl.py \
    .claude/skills/end-session/SKILL.md \
    .claude/skills/end-subagent-session/SKILL.md \
    CLAUDE.md \
    .gitignore \
    agents/memory/agent-network.md
git add agents/*/transcripts/.gitkeep
```

Do NOT use `git add -A` or `git add .` — stage only the files in the manifest. If `git status --short` shows any unstaged changes to files NOT in the manifest, investigate before committing.

Commit (HEREDOC form per CLAUDE.md git rules):

```
git commit -m "$(cat <<'EOF'
chore: /end-session skill Phase 1 — jsonl cleaner, skill files, rule 14, gitignore fix

Ships the /end-session and /end-subagent-session skills per
plans/ready/2026-04-08-end-session-skill-phase-1.md. Phase 1 includes
the Python jsonl cleaner (scripts/clean-jsonl.py), both skill files
under .claude/skills/, CLAUDE.md rule 14 making skill invocation
mandatory, a .gitignore negation so cleaned agent transcripts are
tracked, and a rewrite of the Session Closing Protocol in
agents/memory/agent-network.md to point at the skills.

Privacy note: cleaned transcripts commit verbatim conversation prose.
Cleaner has a hard secret denylist that fails loud (exit 3) on any
match; gitleaks pre-commit is the second line of defense. Duong
accepted the tradeoff 2026-04-08.

Condenser (Syndra component A) deferred to Phase 2. Hard pre-exit
enforcement hook deferred to Phase 2. Subagent interior transcript
preservation deferred to Phase 3.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Then push:
```
git push
```

Verify with:
```
git log -1 --stat
git status --short
```

Expected: clean working tree, the new commit at HEAD, all Phase 1 files in the commit.

### Step 12 — Dry-run the full skill end-to-end (smoke)

Do NOT actually close Katarina's session. The smoke test is manual: Katarina reads through `.claude/skills/end-session/SKILL.md` one more time and mentally walks each step against the current repo state. If any step references a file or command that doesn't resolve, fix the skill body before declaring Phase 1 done.

### Step 13 — Report to Evelynn

Report: Phase 1 shipped, commit hash, any deviations from the plan (ideally none), and the cleaner's reference-diff result from Step 4.

## Section 5 — Verification gates

Per-file verification.

| File | Verification |
|---|---|
| `scripts/clean-jsonl.py` | `python -m py_compile scripts/clean-jsonl.py` exits 0. Smoke diff against reference transcript (Step 4) shows no unacceptable divergences. |
| `.claude/skills/end-session/SKILL.md` | Valid YAML frontmatter (parseable by `python -c "import yaml,sys;yaml.safe_load(open('.claude/skills/end-session/SKILL.md').read().split('---')[1])"` — or just eyeball since it's 4 lines). Body references only Bash/Read/Write/Edit/Glob/Grep tools, matching `allowed-tools`. |
| `.claude/skills/end-subagent-session/SKILL.md` | Same. |
| `CLAUDE.md` | `grep -n '^14\. ' CLAUDE.md` returns exactly one match. Rule 13 still at line 17 (or wherever it is pre-edit). |
| `.gitignore` | `git check-ignore -v agents/evelynn/transcripts/2026-04-08-cafe-to-home-session.md` exits 1. `git check-ignore -v transcripts/x.md` exits 0. |
| `scripts/pre-commit-secrets-guard.sh` | Unmodified. `grep -c 'agents/\.\*/transcripts/' scripts/pre-commit-secrets-guard.sh` returns 1. |
| `agents/memory/agent-network.md` | Section Closing Protocol contains the string `/end-session` and `/end-subagent-session`. No remaining references to the numbered prose steps as the primary protocol. |
| `agents/*/transcripts/.gitkeep` | `ls agents/*/transcripts/.gitkeep` lists one per agent in the manifest. |

### End-to-end smoke

1. From a clean working tree, run the cleaner against today's session (`--agent evelynn --session auto`). Verify the output matches (or strictly supersets) the existing reference transcript.
2. Verify the commit from Step 11 survives `git push` without the pre-push hook rejecting it.
3. Eyeball one cleaned output section to confirm there are zero `tool_use` / `system-reminder` / `claudeMd` leaks.

## Section 6 — Rollback plan

If Phase 1 ships and something goes wrong in the field:

1. **Isolate the breakage.** Which component failed — the cleaner, the skill body, the gitignore negation, the CLAUDE.md rule?
2. **Revert the single commit.** Phase 1 lands as one commit (Section 4 Step 11). Revert with:
   ```
   git revert <phase-1-commit-hash>
   git push
   ```
   This restores the pre-Phase-1 state of every file in the manifest in one move.
3. **Stranded state to clean up after revert:**
   - Any cleaned transcripts written between the commit and the revert remain on disk in `agents/*/transcripts/`. They are tracked in the reverted commit, so `git clean -fd agents/*/transcripts/` after revert removes them. DO NOT run `git clean` without verifying with `-n` first.
   - The empty `.gitkeep` files are removed by the revert. No manual cleanup needed.
   - `.claude/skills/end-session/` and `.claude/skills/end-subagent-session/` directories are removed by the revert. The `.claude/skills/` parent directory will be empty if no other skills have shipped.
4. **Evelynn announces the rollback** and pauses all session closings pending root cause analysis.
5. **Do not re-ship Phase 1 until Bard has updated this plan to address the failure mode.**

## Section 7 — Post-implementation handoff

What comes after Phase 1.

### Phase 2 — the hard enforcement hook (future work, not Phase 1)

Shape sketch, not a spec:

- A pre-session-exit hook that checks for a marker file (`agents/<agent>/memory/.last-close-marker`) updated by the `/end-session` skill on successful completion.
- If the marker is stale (older than the session's start time, derived from the heartbeat registry), the hook refuses to let the session exit cleanly and prints a reminder to invoke `/end-session`.
- Triggered by: Claude Code's session-exit lifecycle hook (if available) or a shell-level trap on the parent iTerm/bash session.
- Marker file format: ISO timestamp + session UUID + agent name, single line.
- Phase 2 plan should spec the marker schema, the hook's trigger, and how it interacts with subagents (which don't have their own exit).

Flag: Phase 2 depends on understanding whether Claude Code exposes a session-exit hook at the harness level. If not, Phase 2 is shell-level only and cannot enforce on top-level sessions that Duong closes via the Claude Code CLI quit path. Research required.

### Syndra's continuity plan component A (condenser)

Phase 1 reserves `/end-session` Step 4 as a no-op with the log line `end-session: condenser step skipped — Phase 2 will wire Syndra's component A here`. When component A lands:

- Syndra's condenser subagent reads the cleaned Markdown transcript produced by Phase 1 (NOT the raw `.jsonl` — this plan asserts that constraint on component A).
- The skill invokes the condenser via the Task tool between the cleaner (Step 2) and the journal step (Step 5), with a 90-second timeout.
- On timeout or absent subagent, the skill logs "condenser unavailable" and proceeds.
- Output goes to `agents/<agent>/memory/last-session-condensed.md`, per Syndra's spec.

Coordination handoff to Syndra: the cleaned Markdown is the stable input contract. Component A's spec should be updated to read `last-session-condensed.md`'s input from `agents/<agent>/transcripts/<date>-<uuid>.md` instead of raw jsonl. Bard flags this to Syndra when component A enters planning.

### `/end-subagent-session` — shipped in Phase 1

Amendment: Bard folded `/end-subagent-session` into Phase 1 rather than deferring to Phase 1.5. The file is ~40 lines and the split-skill design is cleaner shipped together. No separate Phase 1.5 planning cycle needed.

### Open items for Bard (Phase 2 planning)

1. The enforcement hook shape. Research Claude Code's exit lifecycle hooks, if any.
2. The condenser wire-up. Pairs with Syndra's continuity plan component A landing.
3. Subagent interior transcript preservation (the Task/Agent tool_use recognition enhancement). Deferred to Phase 3 per the rough plan.
4. Retention policy for the `transcripts/` directory. Phase 1 has no pruning; revisit quarterly.
5. Multi-session search across `transcripts/`. Becomes Zilean's job per Syndra's continuity plan component B — not Bard's.

## Appendix A — Why Phase 1 ships without the condenser

Per Duong's Q-8 answer: "Confirmed. Ship Phase 1 without waiting on Syndra's component A. Phase 1 writes a rich-enough handoff from the cleaned transcript alone."

The cleaned transcript alone is sufficient for a human-readable handoff, for recovery after a crash, and for retroactive search. The condenser adds structured field extraction ("what plans shipped", "what PRs opened") on top of that, which is valuable but not blocking. Phase 1 makes a cleaner-only close workflow viable; Phase 2 enriches it.

## Appendix B — Explicit non-modifications

Files Katarina does NOT touch in Phase 1:

- `plans/approved/2026-04-08-skills-integration.md` — approved, Bard does not modify approved plans from this detailed spec. The v1 `/close-session` skill item in that plan is superseded by convention (nobody builds it); the plan file's textual mention remains historical.
- `plans/proposed/2026-04-08-end-session-skill.md` — the rough plan, kept as historical reference.
- Any agent profile `.md` file under `agents/<name>/profile.md` — no profile currently references `/close-session` or the session closing protocol by name (verified via grep). Phase 1 does not need to edit any profile.
- Any `.claude/agents/*.md` subagent definition file — none currently has a `skills:` frontmatter field. Adding `skills: [end-session, end-subagent-session]` to these files is a legitimate follow-up, but it is coupled to the broader skills-integration rollout (phases 2+ of that plan) and is NOT required for Phase 1 of `/end-session`. Rule 14 + explicit user invocation carry the enforcement weight.
- `architecture/agent-system.md` — skills-integration plan phase 1 owns the initial skills section in this doc. Phase 1 of this plan does not touch it to avoid merge conflicts with the pending skills-integration work.

## Appendix C — Katarina's S23 extraction rules (reference)

Direct from `agents/katarina/memory/katarina.md` S23 entry, verbatim where the cleaner must match:

> "Extracted the Evelynn day-long session from 4 chronologically-chained jsonl files ... in `~/.claude/projects/C--Users-AD-Duong-strawberry/`. Files live directly in project dir (not nested under session-uuid/). Wrote python one-shot extractor inline: keep only `type==user` string content + assistant `text` blocks, skip `isSidechain` (subagent chains), strip task-notification/local-command-caveat/command-name/local-command-stdout wrappers via startswith check + defensive SR/TN/CAV regex. No system-reminder or claudeMd blocks actually appeared in user content for this session (good — clean signal). Output: `agents/evelynn/transcripts/2026-04-08-cafe-to-home-session.md`, 309 turns (96 Duong / 213 Evelynn), 284KB, 3859 lines, 42716 words."

These are the rules the cleaner must replicate. They produced a clean, human-readable artifact on a ~310-turn real session. Section 2 of this plan is essentially the formalization of Katarina's ad-hoc extractor into a reusable script.
