---
title: Strawberry inbox channel — live inbox ping for coordinator sessions
status: in-progress
owner: azir
date: 2026-04-20
tags: [channels, inbox, coordinator]
---

# Strawberry inbox channel — live inbox ping for coordinator sessions

Short ADR for a local Claude Code Channels plugin that pings running coordinator
sessions (Evelynn, Sona) the instant a new inbox message lands, instead of the
current "notice on next user turn" gap.

## 1. Problem

- Duong runs two top-level coordinators in parallel: Evelynn (personal) and Sona
  (work). They message each other via `/agent-ops send <agent> <msg>`, which
  writes `agents/<agent>/inbox/<ts>-<id>.md` with YAML frontmatter
  (`from`, `to`, `priority`, `timestamp`, `status: pending`).
- The receiving session does not poll the filesystem. New inbox files are
  only discovered at session start (startup protocol reads inbox) or when
  the receiver happens to re-check mid-session.
- Result: time-sensitive pings (e.g. "stop what you're doing, merge PR #62")
  sit unread until the next user turn — which may be hours.

## 2. Decision

Ship a local **Claude Code Channels** plugin, `strawberry-inbox`, that watches
the inbox directory of *exactly one* coordinator (the one that owns the
session) and emits a channel event whenever a new `status: pending` message
appears. The running Claude session picks up the event on idle and surfaces
it to the coordinator, who can then run the companion `/check-inbox` skill.

Channels is the right primitive here (vs. a custom MCP server) because it is
designed precisely for async out-of-band nudges into an active session.
Reference: code.claude.com/docs/en/channels, /channels-reference.

One plugin, parameterised per session. Not two plugins, not a shared watcher.

## 3. Plugin shape

### 3.1 Location

Proposed path: `plugins/strawberry-inbox/` at repo root.

```
plugins/strawberry-inbox/
  package.json           # { "type": "module", "bun": ">=1.1" }
  plugin.json            # Channels plugin manifest
  src/
    index.ts             # entry — registers channel + fs.watch loop
    frontmatter.ts       # minimal YAML frontmatter reader
  README.md
```

Gating Q1 below asks whether `plugins/` is the right top-level slot or whether
this should live under `tools/` or `.claude/plugins/`.

### 3.2 Runtime

- **Bun** (matches Channels plugin examples; no compile step; `fs.watch` is native).
- No npm install in the hot path — plugin ships with its own `bun.lockb`.
- No dependencies beyond Bun stdlib if possible; frontmatter parse is small
  enough to hand-roll (only need `from`, `status`, `priority`).

### 3.3 What it watches

- `fs.watch(agents/<OWNER>/inbox/, { recursive: false })` where `<OWNER>` is
  resolved at plugin start (see §5).
- On `rename` or `change` event with a filename matching `*.md`:
  1. Read file.
  2. Parse frontmatter.
  3. If `status: pending` and `to: <OWNER>` → emit.
  4. Debounce 250 ms to coalesce editor-style atomic writes.

### 3.4 What it emits

Channel event payload:

```json
{
  "channel": "strawberry-inbox",
  "kind": "new-message",
  "from": "sona",
  "to": "evelynn",
  "priority": "normal",
  "path": "agents/evelynn/inbox/2026-04-20T14-02-11-abc123.md",
  "hint": "Run /check-inbox to read and mark pending messages."
}
```

Claude renders this in-session. The `hint` field nudges the coordinator toward
the skill in §4 without forcing it.

## 4. Companion skill — `/check-inbox`

A SlashCommand skill at `.claude/skills/check-inbox/`:

- Determine current agent (same resolution as §5).
- List `agents/<AGENT>/inbox/*.md` with `status: pending`.
- For each: print `from`, `priority`, `timestamp`, body.
- Flip `status: pending` → `status: read`, add `read_at: <ISO>` to frontmatter.
- Leave file in place (audit trail). Housekeeping lives elsewhere.

Gating Q3: auto-mark-read vs. require explicit confirm per-message. Default
proposal: auto-mark-read on display (matches email "mark read on open").

## 5. Identifying the coordinator

The plugin must know whose inbox to watch. Three options:

| Option | How | Pro | Con |
|---|---|---|---|
| A. Launch arg | `claude --channels plugin:strawberry-inbox=agent=evelynn ...` | Explicit, no ambient state | Channels arg-passing syntax is research-preview; API may shift |
| B. Env var | `STRAWBERRY_AGENT=evelynn claude ...` | Universally supported | Ambient state; easy to forget |
| C. `CLAUDE_AGENT_NAME` | Read whatever Claude exposes for `--agent <name>` | Zero extra config; matches existing launcher | Undocumented surface; may not exist |

**Recommendation: C with fallback to B.** The launcher alias already passes
`--agent <name>`; if Claude exports that as an env var into plugin processes,
we get identification for free. If not, fall back to `STRAWBERRY_AGENT`. A is
only a backup if neither works.

Gating Q2 asks Duong to confirm which is preferred.

## 6. Launch wiring

Update `scripts/mac/aliases.sh`:

```sh
alias evelynn='cd ~/Documents/Personal/strawberry-agents && \
  STRAWBERRY_AGENT=evelynn claude --agent evelynn \
  --channels plugin:strawberry-inbox \
  --dangerously-load-development-channels'

alias sona='cd ~/Documents/Personal/strawberry-agents && \
  STRAWBERRY_AGENT=sona claude --agent sona \
  --channels plugin:strawberry-inbox \
  --dangerously-load-development-channels'
```

Windows side (`scripts/windows/`) gets the equivalent once Channels is
confirmed working on Git Bash / PowerShell.

## 7. Failure modes & tradeoffs

- **Session down = missed ping.** The plugin only fires into *running* sessions.
  If Evelynn's terminal is closed, the event is lost. Mitigation: the existing
  startup protocol already reads the inbox on session start, so nothing is
  permanently missed — just deferred to next launch. Acceptable.
- **Channels is v2.1.80+ research preview.** API and flag names may change.
  Plugin is small and local — a rewrite is cheap. Pinning Claude Code version
  in `CLAUDE.md` optional (out of scope here).
- **fs.watch quirks on macOS.** Atomic renames from editors can fire twice
  or as `rename` instead of `change`. Debounce + frontmatter re-read handles it.
- **Two sessions, same repo.** Each session runs its own plugin instance
  watching its own inbox dir. No coordination needed.
- **No recursive watch.** `agents/*/inbox/` with a glob would require one
  watcher per agent dir; overkill. One session watches one dir.

## 8. Out of scope

- Cross-host sync (laptop ↔ desktop inbox delivery).
- Reliable-delivery semantics (at-least-once, retries, ack).
- Auth / permission on the channel (local-only assumption).
- Message queue features (priorities beyond a display hint, TTL, DLQ).
- Non-coordinator agents (Azir, Ekko, etc. don't run persistent sessions).
- Slack/SMS/push bridges. This is in-session only.

## 9. Gating questions for Duong

1. **Plugin location** — is `plugins/strawberry-inbox/` acceptable, or prefer
   `tools/strawberry-inbox/` or `.claude/plugins/strawberry-inbox/`?
2. **Coordinator identification** — OK with "try `CLAUDE_AGENT_NAME`, fall back
   to `STRAWBERRY_AGENT` env var"? Or force the explicit launch-arg form (A)?
3. **Auto-mark-read in `/check-inbox`** — flip `status: read` automatically on
   display, or require `/check-inbox confirm <id>` per message?
4. **Skill name** — `/check-inbox` as proposed, or prefer `/inbox` /
   `/read-inbox` / `/mail`?
5. **Scope of the first cut** — ship watcher + skill together, or land the
   watcher first and leave `/check-inbox` for a follow-up task?

## Gating Answers (approved by Duong 2026-04-20)

| # | Question | Decision |
|---|---|---|
| 1 | Plugin location | `.claude/plugins/strawberry-inbox/` |
| 2 | Coordinator identification | `CLAUDE_AGENT_NAME` env, fallback `STRAWBERRY_AGENT` |
| 3 | Auto-mark-read | Yes — flip `status: read` on display |
| 4 | Skill name | `/check-inbox` |
| 5 | First-cut scope | Bundle plugin + skill as one deliverable |

## 10. Handoff

Once Duong answers the gating questions, this plan promotes to `approved/`
via `scripts/plan-promote.sh` and a task breakdown agent picks it up. Plan
writer does not assign an implementer (per operating protocol).
