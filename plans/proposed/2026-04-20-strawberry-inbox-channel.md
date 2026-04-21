---
title: Strawberry inbox nudge — hook-based coordinator inbox notifications
status: proposed
concern: personal
owner: azir
created: 2026-04-20
date: 2026-04-20
amended: 2026-04-21
orianna_gate_version: 2
tests_required: true
tags: [inbox, coordinator, hooks]
---

# Strawberry inbox nudge — hook-based coordinator inbox notifications

Amended ADR for surfacing unread `agents/<coordinator>/inbox/` messages inside running
coordinator sessions (Evelynn, Sona). The first implementation attempted to use
Claude Code's Channels feature + a plugin-hosted MCP server; that approach is
not viable on this machine (org policy blocks channels, MCP server never
existed). This amendment replaces the Channels-based design with a purely
hook-driven nudge against the existing inbox filesystem schema.

## 0. Amendment context — why the original design failed

The first implementation shipped as three commits (reverted in
`2550097`, `69f4400`, and covered by demote commit `32a70b3`):

- `b3949a9` — `strawberry-inbox` Channels plugin (MCP server under
  `.claude/plugins/strawberry-inbox/`, `fs.watch` loop on the inbox dir,
  250 ms debounce, emits `notifications/claude/channel` events).
- `fb1bd4f` — `/check-inbox` skill reading `status: pending` messages, flipping
  them to `status: read`, adding `read_at` timestamps.
- `385b187` — launcher aliases updated to pass `--channels server:strawberry-inbox
  --dangerously-load-development-channels`.

On the very next session boot, Claude Code refused the wiring with three
distinct errors that together make the Channels path unreachable for us:

1. **Channels feature is org-policy blocked.** Claude Code logged
   `Channels blocked by org policy (server:strawberry-inbox, server:strawberry-inbox)`
   and `Inbound messages will be silently dropped`, with the remediation
   `Have an administrator set channelsEnabled: true in managed settings`.
   That managed setting is not under our control — it gates behind the
   Anthropic/enterprise admin layer. This alone kills the approach.
2. **MCP server name unresolvable.** Claude Code also logged
   `server:strawberry-inbox · no MCP server configured with that name`.
   The channel-arg form `--channels server:<name>` expects a registered MCP
   server; the plugin's `.mcp.json` registration did not surface the server
   under that name into the session's MCP roster, so even with channels
   enabled the channel target would not resolve.
3. **`--dangerously-load-development-channels` is a smell signal.** The
   launcher alias had to set a flag whose own name warns the operator they
   are loading unreleased functionality. The flag is both a fragility
   signal (API may change in any Claude Code release) and proof the Channels
   surface is not intended for routine production use on a managed device.

The `/check-inbox` skill itself worked (it is pure filesystem + frontmatter
rewriting), but without a nudge mechanism it has to be invoked by hand — which
is the exact gap this plan was supposed to close.

**Conclusion:** Channels is not a viable primitive for us. Ship a replacement
using the hook surface that Claude Code does expose to this session today.

## 1. Problem (unchanged from v1)

- Duong runs two top-level coordinators in parallel: Evelynn (personal) and
  Sona (work). They message each other via `/agent-ops send <agent> <msg>`,
  which writes `agents/<agent>/inbox/<ts>-<shortid>.md` with YAML frontmatter
  (`from`, `to`, `priority`, `timestamp`, `status: pending`). Schema is set
  by `.claude/skills/agent-ops/SKILL.md` §`send`.
- The receiving session does not poll the filesystem. New inbox files are
  discovered at session start (startup protocol reads inbox) or when the
  receiver happens to re-check mid-session.
- Result: time-sensitive messages sit unread until the next user turn — which
  may be hours.

What *is* actually available to us on this machine:

- `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
  `SubagentStart`, `SubagentStop`, `PreCompact` hooks — proven working in
  `.claude/settings.json` today (SessionStart already returns
  `hookSpecificOutput.additionalContext` and `systemMessage`).
- POSIX shell, `jq`, `python3`, and the repo working tree.
- The existing `/check-inbox` skill code (recoverable from `fb1bd4f`).

What *is not* available to us:

- Channels (org-policy blocked).
- Registered MCP server named `strawberry-inbox` (never existed).
- Any daemon process we would have to run outside the session lifecycle.

## 2. Decision

Ship **`strawberry-inbox-nudge`**: a hook-based notification mechanism that
injects a one-line `additionalContext` reminder into the coordinator's session
whenever there are `status: pending` messages in the coordinator's inbox. The
existing `/check-inbox` skill (recovered from the revert) reads and marks them.

Two hook call sites:

| Hook | Purpose | Latency |
|------|---------|---------|
| `SessionStart` | Count pending at session boot; inject reminder if > 0 | On boot |
| `UserPromptSubmit` | Count pending on each user turn; inject reminder if > 0 | Next user turn (≤ the cadence of Duong's interaction) |

No daemon. No plugin. No MCP. No channels. No development flag. Every piece
is already supported by Claude Code on this machine today.

This trades **true real-time delivery** (Channels promise) for **next-user-turn
delivery** (hook reality). For Duong's actual usage pattern — he is the human
driving both coordinators and types into them — "next user turn" is within
seconds of when he next speaks, which is sufficient. The failure mode of
Channels (silent drop) is strictly worse than the latency of hooks.

## 3. Architecture

### 3.1 Component layout

```
.claude/
  settings.json                           # wires the two hooks
  skills/check-inbox/SKILL.md             # recovered from fb1bd4f (minor edits)
scripts/hooks/
  inbox-nudge.sh                          # the probe script (new)
agents/<coordinator>/inbox/*.md           # existing schema, unchanged
```

No `.claude/plugins/strawberry-inbox/` directory. No `.mcp.json`. No
`package.json`/`node_modules`. The previous tree is fully reverted.

### 3.2 The probe script — `scripts/hooks/inbox-nudge.sh`

POSIX-portable bash (Rule 10 compliance). Single responsibility: given the
current coordinator identity, count pending inbox messages and emit a hook
response JSON to stdout.

Contract:

- **Input:** hook event JSON on stdin. Reads `.source` (for `SessionStart`)
  and `.cwd` to locate the repo root.
- **Coordinator identity resolution** (in order):
  1. `CLAUDE_AGENT_NAME` env var.
  2. `STRAWBERRY_AGENT` env var.
  3. `.claude/settings.json` `agent` field (which is `"Evelynn"` for this
     repo today — case-insensitive match).
  4. If none resolve, exit 0 silently. A session with no coordinator
     identity is not the target audience for this nudge.
- **Pending count:** `grep -lE '^status: pending$' agents/<agent>/inbox/*.md`
  counted via `wc -l`. Non-existent inbox dir → 0 pending, exit silently.
- **Resume suppression:** if the hook is `SessionStart` with `source` in
  `{resume, clear, compact}`, exit silently. The existing SessionStart hook
  already uses this pattern; the nudge should not duplicate a reminder that
  was already injected pre-resume.
- **Output:** when `pending > 0`, print a single-line JSON of the form:

  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "<SessionStart|UserPromptSubmit>",
      "additionalContext": "INBOX: <N> pending message(s) for <agent>. Run /check-inbox to read them."
    }
  }
  ```

  When `pending == 0`, exit 0 with empty stdout (no-op).

### 3.3 `.claude/settings.json` wiring

Append two hook entries. The existing SessionStart hook continues to handle
resume suppression and that is preserved; the nudge piggybacks as a second
SessionStart entry (Claude Code composes multiple hook entries on the same
event). Concretely:

- Extend the `SessionStart.hooks` array with a second entry:
  `bash scripts/hooks/inbox-nudge.sh`.
- Add a new `UserPromptSubmit` top-level key with a single hook entry:
  `bash scripts/hooks/inbox-nudge.sh`.

No `matcher` keys (the nudge runs for every prompt, independent of tool).

### 3.4 `/check-inbox` skill — recover + harden

Recover `.claude/skills/check-inbox/SKILL.md` from `fb1bd4f` with three small
edits:

1. Drop the "auto-invoked when the strawberry-inbox channel fires" claim from
   the description — there is no channel now. Replace with
   `description: Scan the current coordinator's inbox for pending messages,
   display them, and mark each as read. Invoked manually or after the
   SessionStart / UserPromptSubmit hook surfaces a pending-inbox reminder.`
2. Keep the auto-mark-read behaviour (matches v1 gating answer Q3).
3. Keep the three-way identity resolution (matches v1 gating answer Q2).

### 3.5 Launcher aliases

Revert `scripts/mac/aliases.sh` to its pre-`385b187` form, i.e. drop
`--channels …` and `--dangerously-load-development-channels` completely.
Keep `STRAWBERRY_AGENT=<name>` as a fallback identity for the hook script.

## 4. Data and timing model

- **Schema unchanged.** The nudge reads the same `status: pending` field that
  `/agent-ops send` writes and `/check-inbox` flips. No migration.
- **Ordering guarantee.** `UserPromptSubmit` fires before the model sees the
  user prompt, so the `additionalContext` reaches the model in the same turn
  as the user's message. Duong does not have to type twice.
- **Idempotency.** The nudge prints the same reminder every turn until the
  coordinator actually runs `/check-inbox` (which flips the `status` field).
  That is the feature, not a bug — it refuses to be ignored. If Duong wants
  to suppress it for a specific session, he can `touch .no-inbox-nudge` in
  the repo root and the probe exits silently (mirrors the existing
  `.no-precompact-save` opt-out pattern).
- **Noise ceiling.** The reminder is a single line of additionalContext. Cost
  to context budget is negligible (≈ 20 tokens per turn while mail is
  pending).

## 5. Acceptance criteria

Every criterion is empirically testable with the existing repo + a running
Claude Code session. No "plugin loads" / "MCP registers" criteria — those
were the v1 failure mode.

1. **Boot-time nudge lands within one model turn.**
   - Setup: one `status: pending` file under `agents/evelynn/inbox/`.
   - Action: launch `evelynn` via the updated alias.
   - Expected: the first model response mentions "INBOX: 1 pending message(s)
     for evelynn. Run /check-inbox to read them." or equivalent phrasing
     derived from the injected `additionalContext`.
   - Failure mode if broken: silence (no nudge), or an error line from the
     hook visible in the session trace.

2. **Mid-session arrival surfaces on next user turn.**
   - Setup: running `evelynn` session, empty inbox.
   - Action: from a second terminal, `/agent-ops send evelynn "test ping"`
     (writes a new pending file). Then type any prompt into the evelynn
     session.
   - Expected: the evelynn model's response to that next prompt acknowledges
     the pending inbox message via the injected context.
   - Measured latency: wall-clock between the file landing and the model's
     awareness of it ≤ Duong's own keystroke latency to the next prompt.
     Target ≤ 30 s in normal use.

3. **`/check-inbox` clears the nudge.**
   - Setup: evelynn session with pending messages and the nudge firing.
   - Action: run `/check-inbox`. Then send any prompt.
   - Expected: the `status:` frontmatter of each displayed message is now
     `read` with a `read_at` ISO-8601 timestamp, and the next prompt's
     `additionalContext` injection no longer mentions pending messages.

4. **Resume / clear / compact does not re-nudge.**
   - Setup: evelynn session with no pending messages.
   - Action: `/compact` (via the pre-compact-save workflow). Session resumes.
   - Expected: no INBOX: line appears in the resumed session's system
     context. (The nudge script short-circuits on `source in {resume, clear,
     compact}` exactly like the existing SessionStart hook does.)

5. **No-identity short-circuit.**
   - Setup: invoke the nudge script directly with neither `CLAUDE_AGENT_NAME`
     nor `STRAWBERRY_AGENT` set and `agent` removed from `settings.json`.
   - Expected: exit 0, empty stdout. No error. No nudge.

6. **Unknown-agent short-circuit.**
   - Setup: `CLAUDE_AGENT_NAME=nonexistent` with no such directory under
     `agents/`.
   - Expected: exit 0, empty stdout. No error. No nudge.

7. **No Channels, no MCP server, no dev flag.** Grep the final tree:
   - `grep -r "strawberry-inbox" .claude/plugins` → no matches (dir absent).
   - `grep -r "channelsEnabled\|--channels\|development-channels" scripts
     .claude` → no matches.
   - `find . -name ".mcp.json" -path "*/strawberry-inbox/*"` → no matches.

8. **Pre-existing hooks still work.** The existing SessionStart resume-
   suppression hook and the PreToolUse/PostToolUse hooks continue to fire
   as before. Regression test: a `--resume` launch still emits "Session
   resumed." without any INBOX line.

## 6. Failure modes and tradeoffs

- **Latency.** Worst case the reminder lands on the user's next prompt, not
  in real time. This is the direct tradeoff for losing Channels. For Duong's
  usage (he drives the coordinators; prompts are frequent) the latency is
  bounded by his keystroke cadence, not by any fixed polling interval.
- **Noise if Duong ignores the nudge.** The reminder re-fires every turn
  while mail is pending. Mitigation: `.no-inbox-nudge` opt-out file + the
  fact that `/check-inbox` is one keystroke away.
- **Two sessions, same repo, same inbox dir.** Each session's hook runs its
  own `ls` pass; they don't coordinate. If Evelynn reads and Sona's
  hook fires a beat later, Sona will see zero pending (because Evelynn's
  `/check-inbox` flipped the statuses). Correct behaviour.
- **Hook script failure.** If `scripts/hooks/inbox-nudge.sh` errors (exit
  non-zero with stderr output), Claude Code prints the stderr and continues
  the session. The nudge is advisory — a bug in it never blocks the model.
  We deliberately do not treat nudge failures as hard gates.
- **Cross-host sync.** Out of scope. Same as v1.
- **Non-coordinator agents.** Hook still fires but the identity probe won't
  resolve a coordinator, so the script short-circuits silently. No effect
  on subagent one-shot sessions.

## 7. Out of scope (unchanged from v1)

- Cross-host sync (laptop ↔ desktop inbox delivery).
- Reliable-delivery semantics (at-least-once, retries, ack).
- Auth / permission (local-only assumption).
- Message queue features (priorities beyond a display hint, TTL, DLQ).
- Slack/SMS/push bridges. This is in-session only.
- Resurrecting the `strawberry-inbox` MCP server. If a future plan revisits
  that (e.g. for remote inbox access), it will be a separate plan with its
  own gate.

## 8. Gating questions for Duong (v2)

The v1 gating answers (table below in §10) are **partially superseded** by
this amendment. Specifically:

- Q1 (plugin location) — obsolete. No plugin exists in v2.
- Q2 (coordinator identification) — still relevant; proposal carries the v1
  decision forward (try `CLAUDE_AGENT_NAME`, fall back to
  `STRAWBERRY_AGENT`), extended with a third fallback to
  `.claude/settings.json` `.agent`.
- Q3 (auto-mark-read) — still relevant; carried forward unchanged.
- Q4 (skill name `/check-inbox`) — carried forward unchanged.
- Q5 (bundled vs phased delivery) — revisited below.

New questions:

1. **Nudge phrasing** — OK with
   `INBOX: <N> pending message(s) for <agent>. Run /check-inbox to read them.`,
   or prefer a different wording (e.g. list the senders, include priority
   counts)? Default: the minimal form above — anything longer costs context
   budget per turn.
2. **Opt-out file name** — `.no-inbox-nudge` (mirrors `.no-precompact-save`),
   or a single `.no-nudges` file that future nudges also consume? Default:
   `.no-inbox-nudge` for explicit scoping.
3. **Scope of first cut** — one commit that ships `scripts/hooks/
   inbox-nudge.sh`, re-lands `.claude/skills/check-inbox/SKILL.md`, and
   updates `.claude/settings.json` + `scripts/mac/aliases.sh`? Or split the
   skill and the hook? Default: single commit — they are interlocked.
4. **Windows parity** — Rule 10 says scripts in `scripts/` must be POSIX-
   portable, which `inbox-nudge.sh` will be. Should the initial cut also add
   a `scripts/windows/` alias (the v1 plan deferred this)? Default: defer,
   land mac-first, add Windows parity once the mac path is green.
5. **Regression guard** — add a unit-style test under `scripts/hooks/tests/`
   that feeds fixture inbox directories + fake stdin JSON to
   `inbox-nudge.sh` and asserts the emitted JSON? Default: yes, small
   `bats` or plain bash test harness; this is the primary defence against
   a v3 revert if a future edit breaks the identity probe.

## Test plan

Two levels of test evidence must ship with the implementation. This plan is
structural-level only; the task-breakdown agent translates these into concrete
test tasks post-approval.

- **Unit-level (scripts/hooks/tests/inbox-nudge-test.sh).** Feed fixture inbox
  directories (0 pending, 1 pending, N pending; mixed pending+read; missing
  dir; missing agent) and fake stdin hook-event JSON (`source=startup`,
  `source=resume`, `source=clear`, `source=compact`, and a bare
  `UserPromptSubmit` payload) to `scripts/hooks/inbox-nudge.sh`. Assert on
  stdout JSON shape and exit code. Covers acceptance §5 items 4, 5, 6 and the
  §6 failure-mode "nudge script failure never blocks the model" contract.
- **End-to-end empirical (manual, tracked in assessments/).** Walk the three
  active scenarios in acceptance §5 items 1, 2, 3 against a live `evelynn`
  (and a live `sona`) session. Record wall-clock latency, the exact nudge
  line Claude surfaces, and the final frontmatter state of each touched
  inbox file. Archive under `assessments/qa-reports/<date>-inbox-nudge.md`.
- **Regression floor.** Acceptance §5 item 7 is a one-shot grep check that
  lives in the same unit-level test file, asserting the v1 Channels
  artifacts are not present (no `.claude/plugins/strawberry-inbox/`,
  no `--channels` / `--dangerously-load-development-channels` / `channelsEnabled`
  references in `scripts/` or `.claude/`). This is the primary defence
  against someone resurrecting the v1 path by accident.
- **No new CI jobs.** The unit test plugs into the existing pre-commit hook
  test harness (`scripts/hooks/tests/`). No new workflow, no new required
  check.

## 9. Handoff

Once Duong answers the v2 gating questions above, this plan promotes
`proposed → approved` via `scripts/plan-promote.sh`, which re-opens the
Orianna gate (per Rule 19). A task-breakdown agent picks up execution —
plan writer does not assign.

## 10. Gating Answers — v1 (approved by Duong 2026-04-20, now partially superseded)

Preserved verbatim for audit trail. See §8 above for which remain binding
under v2.

| # | Question (v1) | Decision | v2 status |
|---|---|---|---|
| 1 | Plugin location | `.claude/plugins/strawberry-inbox/` | Obsolete (no plugin) |
| 2 | Coordinator identification | `CLAUDE_AGENT_NAME` env, fallback `STRAWBERRY_AGENT` | Carried forward + settings.json fallback |
| 3 | Auto-mark-read | Yes — flip `status: read` on display | Carried forward |
| 4 | Skill name | `/check-inbox` | Carried forward |
| 5 | First-cut scope | Bundle plugin + skill as one deliverable | Restated: bundle hook + skill as one deliverable |
