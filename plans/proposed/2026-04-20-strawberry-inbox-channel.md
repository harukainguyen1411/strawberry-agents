---
title: Strawberry inbox watcher — Monitor-based autonomous coordinator inbox delivery
status: proposed
concern: personal
owner: azir
created: 2026-04-20
date: 2026-04-20
amended: 2026-04-21
orianna_gate_version: 2
tests_required: true
tags: [inbox, coordinator, hooks, monitor]
---

# Strawberry inbox watcher — Monitor-based autonomous coordinator inbox delivery

ADR for surfacing `agents/<coordinator>/inbox/` messages inside running
coordinator sessions (Evelynn, Sona) in **real time**, with **zero human-in-the-
loop latency** and a **clean inbox lifecycle** (pending vs. archived).

This is the third iteration of the plan:

- **v1** (0828334, 72fb1b5, 9d608bf, implementation b3949a9/fb1bd4f/385b187,
  reverted in 2550097/69f4400/32a70b3): Claude Code Channels + MCP plugin.
  Blocked at runtime by org policy and an unregistered MCP server name.
- **v2** (a3ff998): SessionStart + UserPromptSubmit hooks injecting a
  count-and-nudge `additionalContext` reminder. Correct shape, wrong
  latency — superseded before implementation by this v3 amendment.
- **v3** (this amendment, 2026-04-21): `Monitor` tool running an inbox
  watcher script for the lifetime of the coordinator session. Real-time
  event delivery with no dependency on user turns. Bootstrap via a
  `SessionStart` additionalContext nudge instructing the coordinator to
  invoke `Monitor` on its first turn.

## 0. Amendment context — why v1 and v2 were insufficient

### 0.1 v2 → v3 pivot: "next user turn" is not autonomous enough

v2 proposed a `UserPromptSubmit` hook that counts `status: pending` files on
every user prompt and injects an `INBOX: N pending` nudge into
`additionalContext`. That design is **correct in every dimension except
latency and autonomy**:

1. **Latency floor is the user's keystroke cadence.** If Duong is actively
   driving Sona (work concern) and a high-priority message lands in
   Evelynn's inbox, Evelynn does not notice until Duong next types into
   the Evelynn session. For the cross-coordinator dispatch pattern
   Strawberry is being built around (Sona hands a task off to Evelynn;
   Duong expects Evelynn to pick it up without being re-summoned), this
   is a hard failure: **Evelynn is only nominally "running" — she cannot
   actually react to anything that happens while idle.**
2. **Human-in-loop is a design bug, not a feature.** v2 required Duong to
   physically type a prompt into the receiving session before the
   receiver saw the message. The whole point of two parallel coordinators
   is that Duong only has to drive *one at a time*. v2 broke that
   invariant.
3. **The nudge was a symptom, not a delivery mechanism.** v2 told the
   coordinator "N messages are pending" and expected the coordinator to
   then invoke `/check-inbox`. That is still a pull model on the
   coordinator's side — the message content only surfaces when the
   coordinator chooses to read. For real-time ops work we want **push**:
   the message body arrives as a notification event the coordinator can
   act on in the same turn.

The `Monitor` tool (Claude Code v2.1.98+, documented at
`code.claude.com/docs/en/tools-reference#monitor-tool`) is the primitive
that fixes all three. A Monitor runs a script in the background and
"feeds each output line back to Claude, so it can react to log entries,
file changes, or polled status mid-conversation." Events land on their
own schedule, including while the session is idle waiting for the user.
The session model is already designed to "interject when an event lands."

### 0.2 v1 recap (unchanged, for audit)

The v1 implementation shipped and was reverted in three commits
(`2550097`, `69f4400`, `32a70b3`) because (a) Claude Code logged
`Channels blocked by org policy`, (b) the MCP server name
`strawberry-inbox` never resolved in the session's MCP roster, and (c)
`--dangerously-load-development-channels` is not a flag suitable for
routine production use on a managed device. Full detail preserved in §10.

### 0.3 Inbox lifecycle correction (new in v3)

v1 and v2 both left `status: read` files sitting in
`agents/<coordinator>/inbox/` forever. That was tolerable when the nudge
was pull-based (`/check-inbox` filtered by `status: pending` anyway), but
is **fatal for a real-time watcher**:

- The watcher's initial sweep on boot would re-emit every already-read
  message from months ago.
- Filter discipline on the watcher side becomes brittle — we'd rely on
  `grep status: pending` against a growing pile of `status: read` files.
- The inbox directory becomes un-browsable for humans over time.

v3 makes the lifecycle explicit and enforced: the main `inbox/` directory
is a **pending-only** working set. `/check-inbox` moves each displayed
message to `inbox/archive/YYYY-MM/` with `status: read` and a `read_at`
timestamp. `/agent-ops send` writes to `inbox/` (flat). The watcher only
ever sees pending files.

## 1. Problem (unchanged in substance)

- Duong runs two top-level coordinators in parallel: Evelynn (personal) and
  Sona (work). They message each other via `/agent-ops send <agent> <msg>`,
  which writes `agents/<agent>/inbox/<ts>-<shortid>.md` with YAML
  frontmatter (`from`, `to`, `priority`, `timestamp`, `status: pending`).
  Schema is set by `.claude/skills/agent-ops/SKILL.md` §`send`.
- The receiving session does not poll the filesystem. New inbox files are
  discovered at session start, or when the receiver happens to re-check
  mid-session.
- Result today: time-sensitive messages sit unread indefinitely. A
  coordinator idle waiting for its next prompt has no mechanism to be
  informed a message arrived.

What *is* available to us on this machine:

- **The `Monitor` tool** — runs a background script, feeds each stdout
  line back to Claude as a notification event, lifetime equals the
  session. Permission rules inherit from `Bash`. Requires Claude Code
  v2.1.98+ (we are current). Not available on Bedrock / Vertex /
  Foundry, and auto-disabled when `DISABLE_TELEMETRY` or
  `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` is set — neither applies
  here.
- `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
  `SubagentStart`, `SubagentStop`, `PreCompact` hooks. Hooks cannot
  invoke tools directly, but `SessionStart` can return
  `hookSpecificOutput.additionalContext` that the model acts on in its
  first turn — this is our bootstrap.
- POSIX shell, `jq`, `python3`, the existing repo.
- `fswatch` (Homebrew, common on macOS dev machines) and
  `inotifywait` (Linux). Poll fallback if neither is present.

What *is not* available to us:

- Channels (org-policy blocked).
- Registered MCP server named `strawberry-inbox` (never existed).
- Any daemon process outside the session lifecycle.

## 2. Decision

Ship **`strawberry-inbox-watch`**: a `Monitor`-based real-time inbox
watcher with a clean pending/archive lifecycle.

Three moving parts:

| Component | Role |
|---|---|
| `SessionStart` hook (`additionalContext` only) | **Bootstrap.** Detects coordinator identity; if inbox exists, injects context instructing the coordinator to invoke `Monitor` on its first turn with `bash scripts/hooks/inbox-watch.sh` as the target script. |
| `scripts/hooks/inbox-watch.sh` | **Watcher.** POSIX-portable script the Monitor runs. Emits one stdout line per `status: pending` message — at boot (initial sweep) and on each create/move-in event. Runs for session lifetime. |
| `.claude/skills/check-inbox/SKILL.md` | **Reader + archiver.** Recovered from fb1bd4f and extended. Displays each pending message, then **moves** it to `inbox/archive/YYYY-MM/` with `status: read` + `read_at` set in frontmatter. Enforces the pending-only invariant of the main inbox dir. |

No plugin, no MCP, no channels, no `--dangerously` flag, no daemon. Every
piece is either already supported today or is a POSIX shell script.

### 2.1 Why a hook "nudges" the coordinator to invoke Monitor rather than starting it directly

Hooks cannot invoke tools. The Monitor tool is invoked by the model.
`SessionStart.additionalContext` is the only hook surface that can
reliably cause the model to take a specific first action — and in
practice it does. The existing PostToolUse Agent hook already uses this
pattern (`REMINDER: TaskCreate for subagent …`) and it is reliable.

If at some future point Claude Code's plugin monitors become available
on this machine, we can migrate the bootstrap from "hook nudge →
coordinator invokes Monitor" to "plugin auto-starts Monitor on session
open" (the docs note: "Plugins can declare monitors that start
automatically when the plugin is active"). That is a strictly mechanical
swap; the watcher script and the skill do not change. Noted in §7 as a
future refinement, not a v3 deliverable.

## 3. Architecture

### 3.1 Component layout

```
.claude/
  settings.json                           # adds one SessionStart entry
  skills/check-inbox/SKILL.md             # recovered + archive semantics
scripts/hooks/
  inbox-watch.sh                          # the Monitor-target script (new)
  tests/inbox-watch-test.sh               # unit harness (new)
agents/<coordinator>/
  inbox/*.md                              # pending messages only
  inbox/archive/YYYY-MM/*.md              # read messages, month-bucketed
```

v2's `scripts/hooks/inbox-nudge.sh` is **not created**. The
`UserPromptSubmit` hook described in v2 is **not wired**. The
`SessionStart` hook continues to host resume-suppression logic, and we
add one additional `SessionStart` entry for the watcher bootstrap.

### 3.2 The watcher script — `scripts/hooks/inbox-watch.sh`

POSIX-portable bash (Rule 10 compliance). Two phases:

**Phase 1: boot-time sweep.** Runs once at script start. Lists
`agents/<coordinator>/inbox/*.md` (top-level only — `archive/` is
excluded by pattern, since month-bucket subdirs are not matched by a
flat glob). For each file with `status: pending` in frontmatter, emit
one stdout line. This covers messages that landed while the session was
down.

**Phase 2: live watch.** After the sweep, monitor the same directory
(non-recursive) for new files. Detection order:

1. `fswatch` if present (macOS default once Homebrew-installed):
   `fswatch -x --event Created --event MovedTo agents/<coord>/inbox/`.
2. `inotifywait` if present (Linux): `inotifywait -m -e create -e moved_to
   --format '%f' agents/<coord>/inbox/`.
3. Poll fallback otherwise: `while sleep 3; do ls -1t ...; done`, tracking
   seen filenames in a shell-local set. 3 s cadence balances latency
   (well under a human reaction time) vs. CPU (negligible for a dir with
   < 100 entries).

For each new file the watch layer reports, re-read its frontmatter and
emit a stdout line **only if `status: pending`**. This guard is critical:
it prevents re-emitting on incidental frontmatter edits (e.g., during
the `/check-inbox` flow we briefly flip `status` before moving the file —
any inotify event on that edit must not trigger a re-ping).

**Line format (contract):**

```
INBOX: <filename> — from <sender> — <priority>
```

Example:

```
INBOX: 20260421-1423-sona-alert.md — from sona — high
```

Minimal, action-worthy, and one Monitor event per message. The
coordinator can re-read the full file via the filename when it chooses
to act. We deliberately do not echo the message body — that would bloat
the Monitor event stream and defeat `/check-inbox`'s archiving flow.

**Coordinator identity resolution** (in order):

1. `CLAUDE_AGENT_NAME` env var.
2. `STRAWBERRY_AGENT` env var.
3. `.claude/settings.json` `.agent` field (currently `"Evelynn"`),
   case-insensitive.
4. If none resolve, exit 0 silently (no coordinator = no target).

**Opt-out:** if `.no-inbox-watch` exists at repo root, exit 0 silently
before phase 1. Per-session escape hatch (touch it, restart the
session; Monitor dies with the session anyway).

**Lifecycle:** script runs until Monitor is stopped (TaskStop) or the
session ends. If `fswatch`/`inotifywait` exits nonzero (rare —
directory deleted, permissions change), the script logs to stderr and
exits. Monitor reports the exit; coordinator can restart it. We do not
add internal restart logic — keep the script simple; let the tool
surface the failure.

**One-shot mode (for tests):** if `INBOX_WATCH_ONESHOT=1` is set, run
phase 1 only and exit. The regression harness uses this path.

### 3.3 The bootstrap nudge — `SessionStart` additionalContext

Add a second `SessionStart` hook entry in `.claude/settings.json`. This
entry:

1. Runs **after** the existing resume-suppression entry (which short-
   circuits on `source in {resume, clear, compact}`). On those three
   sources we do **not** bootstrap a new Monitor — the previous session's
   Monitor is already stopped, but the user is resuming an active
   session and re-starting the Monitor in a compacted turn would be
   noisy. The coordinator can restart it on demand. Document this in §6.
2. On `source=startup`, emits `hookSpecificOutput.additionalContext`
   with text of roughly the form:

   ```
   INBOX WATCHER: invoke the Monitor tool on your first action with:
     command: bash scripts/hooks/inbox-watch.sh
     description: Watch <agent>'s inbox for new messages.
   Events will surface as INBOX: … notifications. When you see one,
   run /check-inbox to read and archive the message.
   ```

3. Short-circuits silently if the coordinator identity is unresolved or
   `.no-inbox-watch` exists.

The nudge is idempotent: if for any reason the coordinator invokes
Monitor twice, the second instance performs a redundant sweep and then
quietly duplicates events for the session. We accept this as a soft
failure (it's visible and self-correcting — the coordinator can
`TaskStop` the dupe).

### 3.4 `/check-inbox` skill — recover and extend

Recover `.claude/skills/check-inbox/SKILL.md` from `fb1bd4f`, then
rewrite the disposition step. New behaviour:

For each file matching `agents/<coord>/inbox/*.md` with `status:
pending`:

1. Read the message, display it to the coordinator (frontmatter +
   body).
2. Rewrite the frontmatter in place: `status: read`, add
   `read_at: <ISO-8601 UTC>`.
3. Compute the archive path: `agents/<coord>/inbox/archive/<YYYY-MM>/
   <original-filename>` where `<YYYY-MM>` is derived from the file's
   `timestamp:` frontmatter field (fallback: file mtime).
4. `mkdir -p` the month-bucket, then `mv` the file into it.
5. After processing all files, the main `inbox/` directory contains
   zero `status: pending` files (the post-condition).

**Identity resolution:** same three-way fallback as the watcher.

**Concurrency:** if two sessions run `/check-inbox` against the same
inbox (shouldn't happen in practice — Evelynn and Sona have separate
inboxes), the second `mv` fails because the source is gone; we skip
and continue. Idempotent.

**Why month buckets.** `YYYY-MM/` is the right granularity for a human
scanning the archive a month later (`ls inbox/archive/2026-04/`
immediately answers "what did I get in April?"). Year buckets
(`YYYY/`) accumulate too fast; day buckets (`YYYY-MM-DD/`) fragment
too much. Month also matches how Duong already organizes transcripts
(daily → month folder on archive).

### 3.5 `.claude/settings.json` wiring

Append one hook entry under `SessionStart.hooks` (as a sibling of the
existing resume-suppression entry):

```json
{
  "type": "command",
  "command": "bash scripts/hooks/inbox-watch-bootstrap.sh"
}
```

`inbox-watch-bootstrap.sh` is a tiny wrapper (can be inlined as a jq
one-liner if simple enough; we keep it a script for testability) that:

- Reads stdin; if `source != startup`, exits 0.
- Resolves coordinator identity (same chain).
- Checks for `.no-inbox-watch`; exits 0 if present.
- Emits `{"hookSpecificOutput":{"hookEventName":"SessionStart",
  "additionalContext": "<bootstrap nudge>"}}` to stdout.

No `UserPromptSubmit` entry. No `PreToolUse` entry. v2's
`UserPromptSubmit.inbox-nudge` is explicitly **not** added.

### 3.6 Launcher aliases

Unchanged from v2 baseline: `STRAWBERRY_AGENT=<name>` remains as an
identity fallback. No `--channels` / `--dangerously-load-development-
channels`. Nothing to add for Monitor itself (the tool is always on when
the session is on a supported platform).

## 4. Data, timing, and lifecycle model

### 4.1 Message states and transitions

```
           /agent-ops send                        /check-inbox
(no file)  ───────────────▶  inbox/<name>.md  ───────────────▶  inbox/archive/YYYY-MM/<name>.md
                             status: pending                     status: read, read_at: ...
                                    │
                                    │  (inbox-watch.sh observes, emits Monitor event)
                                    ▼
                             coordinator sees
                             "INBOX: <name> ..."
```

Invariant: the top level of `agents/<coord>/inbox/` contains **only**
`status: pending` files. `archive/` contains **only** `status: read`
files. `/agent-ops send` always writes to `inbox/` (flat, never
`archive/`). `/check-inbox` is the only writer of `archive/`.

### 4.2 Timing

- **Boot-time latency** (message arrived before session start →
  coordinator sees it): one initial sweep inside Phase 1 of the
  watcher. Bounded by the time for the coordinator's first Monitor
  invocation (which is the first tool call after reading the
  `SessionStart` nudge). Target ≤ 5 s end-to-end.
- **Live latency** (message arrives mid-session):
  - `fswatch` / `inotifywait` path: sub-second — these are kernel-level
    notifications.
  - Poll fallback: bounded by the poll interval (3 s).
- **Idle delivery:** Monitor events surface even while the session is
  idle waiting for user input — this is the property that makes v3
  superior to v2.

### 4.3 Volume and filter discipline

Inbox traffic is low volume by design (human-speed messaging between two
coordinators — expect < 20 events per session, usually < 5). The
watcher's "only emit on `status: pending`" filter keeps the event rate
bounded. The Monitor auto-kill rule ("noisy monitors are auto-killed")
should not trigger in practice; if it does, the coordinator restarts
the Monitor (same mechanic as the initial bootstrap, invoked by hand).

## 5. Acceptance criteria

All criteria empirically testable against a live session.

1. **Boot-time message surfaces within one turn.**
   - Setup: one `status: pending` file in `agents/evelynn/inbox/`;
     `agents/evelynn/inbox/archive/` empty or populated with read
     messages.
   - Action: launch `evelynn`. Observe the model's first turn.
   - Expected: the model's first turn invokes `Monitor` with
     `bash scripts/hooks/inbox-watch.sh`. Within a few seconds of
     Monitor starting, the session receives an `INBOX: <filename> —
     from <sender> — <priority>` notification event.

2. **Mid-session, idle-session delivery works.**
   - Setup: running `evelynn` session, empty inbox, Monitor active.
     Session is **idle** (no user prompt in flight).
   - Action: from a second terminal, `/agent-ops send evelynn "test
     ping"`.
   - Expected: evelynn session receives an `INBOX:` event
     autonomously, without Duong typing anything into evelynn first.
     Target latency ≤ 5 s (kernel-notify path) or ≤ 5 s (poll path,
     3 s worst case + emit).

3. **`/check-inbox` archives and clears the inbox.**
   - Setup: evelynn session with ≥ 1 pending message; Monitor has
     emitted at least one `INBOX:` event.
   - Action: coordinator invokes `/check-inbox`.
   - Expected post-state:
     (a) `agents/evelynn/inbox/` contains zero `status: pending`
         files (it may contain the `archive/` subdir; nothing else).
     (b) Each previously-pending file is now under
         `agents/evelynn/inbox/archive/<YYYY-MM>/` with
         `status: read` and a `read_at` ISO-8601 UTC timestamp.
     (c) Monitor did not emit a duplicate `INBOX:` event triggered by
         the frontmatter rewrite (filter discipline).

4. **`/agent-ops send` writes to `inbox/`, never `archive/`.**
   - Grep / code-read check: `.claude/skills/agent-ops/SKILL.md` §`send`
     writes to `agents/<to>/inbox/<name>.md` only. No reference to
     `archive/` in the send path.

5. **Resume / clear / compact does not re-bootstrap.**
   - Setup: running session, Monitor already active.
   - Action: `/compact`; session resumes.
   - Expected: no additional "invoke Monitor" nudge in the resumed
     turn. The previous Monitor is gone; coordinator may restart it
     manually if desired. No INBOX: spam on resume.

6. **No-identity short-circuit.** Invoke bootstrap and watcher
   directly with no identity env vars and `agent` stripped from
   `settings.json`. Expected: both exit 0, empty stdout.

7. **Unknown-agent short-circuit.** Invoke with
   `CLAUDE_AGENT_NAME=nonexistent` and no such directory. Expected:
   exit 0, empty stdout.

8. **Opt-out honored.** `touch .no-inbox-watch`; rerun. Expected:
   bootstrap script and watcher both exit 0 silently.

9. **No Channels / MCP / dev-flag regressions.**
   - `grep -r "strawberry-inbox" .claude/plugins` → no matches.
   - `grep -r "channelsEnabled\|--channels\|development-channels"
     scripts .claude` → no matches.
   - `find . -name ".mcp.json" -path "*/strawberry-inbox/*"` → no
     matches.

10. **No v2 nudge regressions.**
    - `.claude/settings.json` has no `UserPromptSubmit` entry
      referencing `inbox-nudge` or `inbox-watch`.
    - `scripts/hooks/` does not contain `inbox-nudge.sh`.
    - No `additionalContext` string anywhere in `scripts/hooks/`
      matches the v2 phrasing `"pending message(s).*Run /check-inbox
      to read them."`.

11. **Watcher filter discipline holds under `/check-inbox` edit.**
    - Setup: pending file; Monitor active. Start `/check-inbox`.
      Watcher observes the frontmatter rewrite (status: pending →
      read) and the subsequent move.
    - Expected: no **second** `INBOX:` event for the same filename
      during the read/move window. (Filter: emit only when the file
      read after the watch event shows `status: pending`. The
      in-flight `read` rewrite fails that check; the post-move file is
      no longer in the watched path.)

## 6. Failure modes and tradeoffs

- **Monitor not available** (Bedrock / Vertex / Foundry / telemetry
  disabled): the bootstrap nudge still fires, the coordinator attempts
  to invoke Monitor, the tool reports "not available." The coordinator
  falls back to manual `/check-inbox`. Document in §7; we do not build
  a nudge fallback in v3.
- **Coordinator forgets to invoke Monitor on its first turn.**
  Worst case: same as pre-nudge v1 — messages sit until the
  coordinator next runs `/check-inbox` manually. The
  `additionalContext` is our best lever here; in practice the existing
  PostToolUse Agent hook (which uses the same `additionalContext`
  pattern for a similar "do this on next turn" reminder) is reliable.
- **Session compact / restart** kills the Monitor (session-lifetime
  scope). SessionStart's resume/clear/compact short-circuit means we
  do **not** auto-re-nudge on resume — the coordinator can restart
  Monitor explicitly if needed. Rationale: we don't want
  compaction-induced Monitor spam; a resumed session is a user-driven
  resumption, user can ask for the watcher.
- **fswatch / inotifywait missing.** Poll fallback at 3 s intervals.
  Document in §3.2. Latency for live delivery degrades from sub-
  second to ≤ 3 s — still well inside the "autonomous" budget.
- **Noisy-monitor auto-kill.** Duong's traffic model (low volume) plus
  the `status: pending` filter keeps event rate tiny. If it ever
  triggers, the watcher log shows the kill; coordinator restarts.
  Flag in the regression grep: make sure no accidental `echo`/debug
  line leaks into the stdout stream.
- **`/check-inbox` race with Monitor.** Acceptance §11. Filter must
  read the file state *at emit time*, not trust the fswatch event
  alone. This is the most subtle v3 bug class; dedicated unit test.
- **Two coordinators, same checkout.** Each resolves its own identity,
  watches its own `agents/<name>/inbox/`. No cross-interference.
- **Archive dir accidentally watched.** The watcher's glob is flat
  (`inbox/*.md`), not recursive. `archive/` subdirs are not watched.
  Unit test confirms.
- **Frontmatter without `timestamp:`.** `/check-inbox` archive path
  computation falls back to file mtime's `YYYY-MM`. No failure, but
  sender-side `/agent-ops send` always writes `timestamp:`, so the
  fallback is a belt-and-braces.
- **Cross-host sync.** Out of scope. Same as v1 / v2.

## 7. Out of scope (deferred)

- Cross-host sync (laptop ↔ desktop inbox delivery).
- Reliable-delivery semantics (at-least-once, retries, ack).
- Plugin-declared auto-starting Monitors — viable on platforms that
  support `plugins-reference#monitors`, but requires plugin
  infrastructure we do not have today. Revisit if Channels block
  lifts; strictly mechanical swap at the bootstrap layer.
- Windows parity — `scripts/hooks/inbox-watch.sh` will be POSIX, but
  `fswatch`/`inotifywait` detection + PowerShell equivalents are a
  follow-up. Default: defer (§8 Q4).
- Slack/SMS/push bridges. In-session only.
- A richer notification schema than the one-line contract (e.g. JSON
  events with structured fields). Keep v3 minimal; revisit if Duong
  wants richer filtering on the coordinator side.

## 8. Gating questions for Duong (v3)

Carry-forward decisions from v1 (table below in §10) remain binding
unless noted here. New or revisited for v3:

1. **Read-flow disposition — archive vs. hard-delete?**
   (a) Archive under `inbox/archive/<YYYY-MM>/` with `status: read` +
       `read_at` (default — full audit trail, browsable).
   (b) Hard-delete after display (zero clutter, no history).
   Proposal defaults to (a). Duong's v3 briefing wording
   ("archived or deleted entirely") signals he is open to either.
   **Pick one.**

2. **Archive bucket granularity — `YYYY-MM/` / `YYYY/` / flat?**
   Default: `YYYY-MM/` (§3.4 rationale). Confirm or override.

3. **Monitor event line format.**
   Default: `INBOX: <filename> — from <sender> — <priority>`.
   Alternatives:
   (a) Add message first-line preview (richer but costs stream
       budget and body may contain noise).
   (b) Strip priority (shorter but loses the triage hint that
       Sona/Evelynn priority protocols rely on).
   (c) JSON-encoded line (structured but requires coordinator to
       parse; Claude handles JSON fine but adds verbosity).
   Pick one; proposal defaults to the minimal three-field form.

4. **Windows parity scope.**
   (a) Defer — mac/linux first, Windows follow-up after v3 is green
       (proposal default).
   (b) Bundle — add PowerShell watcher equivalent in the same cut.

5. **Opt-out filename.**
   (a) `.no-inbox-watch` — explicit scoping, mirrors
       `.no-precompact-save` (proposal default).
   (b) `.no-nudges` — shared file for all future nudge mechanisms.
   Pick one.

6. **Scope of first cut — single commit?**
   The watcher script, the bootstrap script, the `check-inbox` skill
   recovery + archive semantics, the `settings.json` wiring, and the
   unit harness are interlocked (none works in isolation). Proposal:
   single commit (or a tight stack of PR-gated commits, per the
   implementer's TDD preference). Confirm.

## Test plan

Three layers of test evidence.

- **Unit-level (`scripts/hooks/tests/inbox-watch-test.sh`).**
  Covers:
  - Initial-sweep correctness (`INBOX_WATCH_ONESHOT=1`): fixture inbox
    dirs with 0 / 1 / N pending files, mixed pending + read (archive
    subdir populated), missing inbox dir, missing agent dir. Assert
    on emitted lines.
  - Line format contract: regex match against `^INBOX: [^ ]+\.md — from
    [^ ]+ — [a-z]+$`.
  - Identity resolution chain: each of the three sources in turn, plus
    the unresolved-exit case.
  - `.no-inbox-watch` opt-out honored.
  - `archive/` subdirs are not swept.
  - Frontmatter without `status:` field never emits.
  - Frontmatter with `status: read` never emits.

- **`/check-inbox` archive-flow test (same harness, separate case).**
  - Create a pending file with a known `timestamp:` (say
    `2026-04-21T14:23:00Z`). Run the archive routine. Assert:
    - `agents/<coord>/inbox/` has zero `status: pending` files.
    - `agents/<coord>/inbox/archive/2026-04/<original-filename>`
      exists.
    - Archived file's frontmatter: `status: read`, `read_at:` is a
      valid ISO-8601 UTC string.
  - Edge: file with no `timestamp:` frontmatter — archive path falls
    back to mtime's `YYYY-MM`.

- **Regression floor (same harness).**
  - `grep -rn "strawberry-inbox" .claude/plugins` → no matches
    (directory absent).
  - `grep -rn "channelsEnabled\|--channels\|development-channels"
    scripts/ .claude/` → no matches.
  - `grep -rn "UserPromptSubmit" .claude/settings.json` does not name
    an inbox-nudge / inbox-watch command.
  - `scripts/hooks/inbox-nudge.sh` does not exist.
  - No string `"pending message(s). Run /check-inbox to read them."`
    appears in `scripts/hooks/` (v2 phrasing fingerprint).

- **End-to-end empirical (manual, archived under
  `assessments/qa-reports/<date>-inbox-watch.md`).** Walk acceptance
  criteria §5 items 1, 2, 3, 5, 11 against a live Evelynn and a live
  Sona. Record wall-clock latency, exact Monitor event text, and
  final inbox + archive directory state. Failing criteria block
  promotion past in-progress.

- **No new CI jobs.** The unit harness plugs into the existing
  pre-commit hook test harness (`scripts/hooks/tests/`).

## 9. Handoff

Once Duong answers the v3 gating questions (§8), this plan promotes
`proposed → approved` via `scripts/plan-promote.sh`, which re-opens
the Orianna gate (Rule 19). A task-breakdown agent picks up execution
— plan writer does not assign.

## 10. Prior gating answers and v3 status

### v1 gating answers (approved 2026-04-20, now mostly obsolete)

Preserved verbatim for audit trail.

| # | Question (v1) | v1 decision | v2 status | v3 status |
|---|---|---|---|---|
| 1 | Plugin location | `.claude/plugins/strawberry-inbox/` | Obsolete (no plugin) | Obsolete |
| 2 | Coordinator identification | `CLAUDE_AGENT_NAME`, fallback `STRAWBERRY_AGENT` | Carried + `.claude/settings.json .agent` fallback | **Carried forward (v2 chain)** |
| 3 | Auto-mark-read | Yes — flip `status: read` on display | Carried | **Superseded**: move to `archive/YYYY-MM/` with `status: read` + `read_at` |
| 4 | Skill name | `/check-inbox` | Carried | **Carried forward** |
| 5 | First-cut scope | Bundle plugin + skill as one deliverable | Restated as hook + skill | **Restated as Monitor watcher + bootstrap + skill + tests as one cut** |

### v2 gating proposals (superseded without being answered)

v2 was amended to v3 before Duong ruled on its gating questions.
For completeness:

| # | Question (v2) | v2 proposed default | v3 disposition |
|---|---|---|---|
| 1 | Nudge phrasing | `INBOX: <N> pending message(s) for <agent>. Run /check-inbox to read them.` | **Obsolete**: v3 emits per-message Monitor events, not a count. New line contract in §8 Q3. |
| 2 | Opt-out filename | `.no-inbox-nudge` | **Renamed** to `.no-inbox-watch`; question re-asked in §8 Q5 |
| 3 | First-cut scope | Single commit | **Carried forward** (§8 Q6) |
| 4 | Windows parity | Defer | **Carried forward** (§8 Q4) |
| 5 | Regression guard | Yes, under `scripts/hooks/tests/` | **Carried forward and expanded** (now covers archive-flow as well as watcher) |
