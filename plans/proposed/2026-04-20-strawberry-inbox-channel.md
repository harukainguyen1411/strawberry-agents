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
- **v3** (2026-04-21, first amendment): `Monitor` tool running an inbox
  watcher script for the lifetime of the coordinator session. Real-time
  event delivery with no dependency on user turns. Bootstrap via a
  `SessionStart` additionalContext nudge instructing the coordinator to
  invoke `Monitor` on its first turn.
- **v3.1** (this amendment, 2026-04-21, second amendment): Duong's
  answers to the v3 gating questions inlined into the design. Archive
  retention policy added — `inbox/archive/**` entries older than 7 days
  are deleted on next watcher boot (cleanup runs once per session, at
  the top of `inbox-watch.sh`, before the initial pending sweep). §8 <!-- orianna: ok -->
  gating block closed; answers preserved as a v3 table in §10 alongside
  the v1 / v2 tables.

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
| `SessionStart` hook (`additionalContext` only) | **Bootstrap.** Detects coordinator identity; if inbox exists, injects context instructing the coordinator to invoke `Monitor` on its first turn with `bash scripts/hooks/inbox-watch.sh` as the target script. | <!-- orianna: ok -->
| `scripts/hooks/inbox-watch.sh` | **Watcher.** POSIX-portable script the Monitor runs. Emits one stdout line per `status: pending` message — at boot (initial sweep) and on each create/move-in event. Runs for session lifetime. | <!-- orianna: ok -->
| `.claude/skills/check-inbox/SKILL.md` | **Reader + archiver.** Recovered from fb1bd4f and extended. Displays each pending message, then **moves** it to `inbox/archive/YYYY-MM/` with `status: read` + `read_at` set in frontmatter. Enforces the pending-only invariant of the main inbox dir. | <!-- orianna: ok -->

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

### 3.2 The watcher script — `scripts/hooks/inbox-watch.sh` <!-- orianna: ok -->

POSIX-portable bash (Rule 10 compliance). Three phases, run in order:

**Phase 0: archive cleanup (one-shot, per session boot).** Runs once at
script start, before any emission. Deletes files in
`agents/<coordinator>/inbox/archive/**` whose mtime is older than 7
days, then prunes empty month-bucket directories:

```sh
find "agents/${coord}/inbox/archive" -type f -name '*.md' -mtime +7 -delete 2>/dev/null
find "agents/${coord}/inbox/archive" -type d -empty -delete 2>/dev/null
```

`-mtime +7` is POSIX-defined as "more than 7 full 24-hour periods ago"
relative to the file's mtime — a well-defined wall-clock rule that does
not drift on DST transitions. The `2>/dev/null` suppresses noise when
the archive dir does not exist yet (fresh coordinator, first boot). If
the watcher never boots for > 7 days (e.g. coordinator offline for a
long trip), cleanup simply runs later on the next boot: no data loss,
slight retention overshoot. This behaviour is deliberate — we do not
add a cron, a systemd timer, or a scheduled skill; the watcher is the
sole enforcer of the retention TTL and it only runs when the
coordinator is live. See §4.4 for the retention model.

**Phase 1: boot-time pending sweep.** Runs once after Phase 0. Lists
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

**Line format (contract, settled §10 v3 table Q3):**

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

**Opt-out (settled §10 v3 table Q5):** if `.no-inbox-watch` exists at
repo root, exit 0 silently before Phase 0 (so opt-out also suppresses
the archive-cleanup sweep — the opt-out is total, not partial). Per-
session escape hatch (touch it, restart the session; Monitor dies with
the session anyway).

**Lifecycle:** script runs until Monitor is stopped (TaskStop) or the
session ends. If `fswatch`/`inotifywait` exits nonzero (rare —
directory deleted, permissions change), the script logs to stderr and
exits. Monitor reports the exit; coordinator can restart it. We do not
add internal restart logic — keep the script simple; let the tool
surface the failure.

**One-shot mode (for tests):** if `INBOX_WATCH_ONESHOT=1` is set, run
Phase 0 (archive cleanup) + Phase 1 (pending sweep) and exit — Phase 2
is skipped. The regression harness uses this path to cover both the
cleanup and the sweep in a single invocation.

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

Read-flow disposition is **archive** (settled §10 v3 table Q1) — not
hard-delete — with a 7-day TTL on archived entries enforced by the
watcher (§3.2 Phase 0, §4.4). Archive bucket granularity is
`YYYY-MM/` (settled §10 v3 table Q2).

Recover `.claude/skills/check-inbox/SKILL.md` from `fb1bd4f`, then <!-- orianna: ok -->
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
(daily → month folder on archive). The 7-day retention (§4.4) means
each bucket typically holds at most one month's trailing week of read
messages — small enough that `mv` and `find` stay O(ms).

### 3.5 `.claude/settings.json` wiring

Append one hook entry under `SessionStart.hooks` (as a sibling of the
existing resume-suppression entry):

```json
{
  "type": "command",
  "command": "bash scripts/hooks/inbox-watch-bootstrap.sh"
}
```

`inbox-watch-bootstrap.sh` is a tiny wrapper (can be inlined as a jq <!-- orianna: ok -->
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
                                    │                                           │
                                    │  (inbox-watch.sh observes)                │  (inbox-watch.sh Phase 0,
                                    ▼                                           ▼   next session boot,
                             coordinator sees                               mtime > 7 days:
                             "INBOX: <name> ..."                            find … -delete)
                                                                                │
                                                                                ▼
                                                                           (no file)
```

Invariant: the top level of `agents/<coord>/inbox/` contains **only**
`status: pending` files. `archive/` contains **only** `status: read`
files. `/agent-ops send` always writes to `inbox/` (flat, never
`archive/`). `/check-inbox` is the only writer of `archive/`. The
watcher's Phase 0 is the only **deleter** of `archive/` entries (see
§4.4).

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

### 4.4 Retention — 7-day TTL on `inbox/archive/**`

Archive retention is **7 days from file mtime**, enforced by the
watcher's Phase 0 at every session boot (§3.2). Semantics:

- **TTL basis**: file mtime. `/check-inbox` creates the archived file
  via `mv`; `mv` preserves mtime from the pre-archive file, which was
  last written when `/check-inbox` rewrote its frontmatter (status →
  read, read_at: …). So the effective TTL clock starts the moment the
  coordinator read the message. That is the right anchor: "keep read
  messages for 7 days after they were read."
- **Enforcement cadence**: once per session boot of the receiving
  coordinator. No cron, no systemd timer, no scheduled skill.
- **Overshoot bound**: if the coordinator session boots every day,
  retention is 7 days ± hours. If the coordinator stays offline for
  N days (N > 7), retention overshoots to N days on the late bookings.
  Next boot catches up; nothing is leaked to a remote system.
  Acceptable — this is a local audit trail, not a compliance
  obligation.
- **Undershoot bound**: never. `-mtime +7` is strictly "more than 7
  full 24-hour periods" (POSIX), so a file read less than 7×24 h ago
  cannot be deleted, even if a session boots 6 days 23 hours later.
- **Opt-out interaction**: if `.no-inbox-watch` exists, the watcher
  exits before Phase 0, so cleanup is **also** suspended. A user who
  wants to freeze the archive (e.g. for a specific debug session)
  gets that by opting out of the whole watcher; there is no finer-
  grained opt-out for cleanup alone. Documented in §3.2.
- **No retention on the pending set**: `inbox/*.md` (pending messages)
  are not subject to any TTL. A message that was never read sits until
  `/check-inbox` moves it. That is the correct semantic — we must not
  silently drop unread mail.

## 5. Acceptance criteria

All criteria empirically testable against a live session.

1. **Boot-time message surfaces within one turn.**
   - Setup: one `status: pending` file in `agents/evelynn/inbox/`;
     `agents/evelynn/inbox/archive/` empty or populated with read
     messages.
   - Action: launch `evelynn`. Observe the model's first turn.
   - Expected: the model's first turn invokes `Monitor` with
     `bash scripts/hooks/inbox-watch.sh`. Within a few seconds of <!-- orianna: ok -->
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

12. **Archive retention — 7-day TTL on next watcher boot.**
    - Setup:
      `agents/<coord>/inbox/archive/2026-03/old-msg.md` with mtime
      backdated to 10 days ago (e.g. `touch -t` or
      `-d '10 days ago'`), and
      `agents/<coord>/inbox/archive/2026-04/fresh-msg.md` with mtime
      within the last 24 h.
    - Action: run `scripts/hooks/inbox-watch.sh` with <!-- orianna: ok -->
      `INBOX_WATCH_ONESHOT=1` (runs Phase 0 then Phase 1).
    - Expected:
      (a) `old-msg.md` is deleted.
      (b) `fresh-msg.md` remains.
      (c) If `archive/2026-03/` is now empty, the directory itself is
          also pruned; `archive/2026-04/` survives because it still
          has a child.
      (d) Phase 1 still executes correctly afterward (pending sweep
          unchanged by Phase 0's work).

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
- **Retention TTL + timezone / DST.** `find -mtime +N` uses the file
  mtime and 24-hour arithmetic against the *current* clock. POSIX
  guarantees the semantics ("more than N full 24-hour periods ago"),
  independent of local timezone or DST transitions. Confirmed on
  macOS BSD `find` and GNU `find` both. No caveat required.
- **Coordinator offline > 7 days.** If the coordinator session is not
  booted for longer than the retention window, archive cleanup simply
  runs at the next boot. Files overshoot the 7-day window by however
  long the offline period lasted, then are collected in the next
  sweep. No data loss. No risk of the archive growing unbounded
  (catch-up is O(n) over the archive tree, and the tree is small —
  inbox traffic is low volume).
- **Cross-host sync.** Out of scope. Same as v1 / v2.

## 7. Out of scope (deferred)

- Cross-host sync (laptop ↔ desktop inbox delivery).
- Reliable-delivery semantics (at-least-once, retries, ack).
- Plugin-declared auto-starting Monitors — viable on platforms that
  support `plugins-reference#monitors`, but requires plugin
  infrastructure we do not have today. Revisit if Channels block
  lifts; strictly mechanical swap at the bootstrap layer.
- Windows parity — `scripts/hooks/inbox-watch.sh` will be POSIX, but <!-- orianna: ok -->
  `fswatch`/`inotifywait` detection + PowerShell equivalents are a
  follow-up. Deferred (settled §10 v3 table Q4).
- Slack/SMS/push bridges. In-session only.
- A richer notification schema than the one-line contract (e.g. JSON
  events with structured fields). Keep v3 minimal; revisit if Duong
  wants richer filtering on the coordinator side.

## 8. Gating questions for Duong (v3)

**Closed.** Duong answered all six v3 gating questions on 2026-04-21.
Answers are inlined into the design body (§3.2, §3.4, §4.4) and
preserved in the v3 gating-answers table in §10.

No open gating questions remain for this plan. Next transition:
`proposed → approved` via `scripts/plan-promote.sh`, which runs the
Orianna gate (Rule 19).

## Test plan

Three layers of test evidence.

- **Unit-level (`scripts/hooks/tests/inbox-watch-test.sh`).** <!-- orianna: ok -->
  Covers:
  - Initial-sweep correctness (`INBOX_WATCH_ONESHOT=1`): fixture inbox
    dirs with 0 / 1 / N pending files, mixed pending + read (archive
    subdir populated), missing inbox dir, missing agent dir. Assert
    on emitted lines.
  - Line format contract: regex match against `^INBOX: [^ ]+\.md — from
    [^ ]+ — [a-z]+$`.
  - Identity resolution chain: each of the three sources in turn, plus
    the unresolved-exit case.
  - `.no-inbox-watch` opt-out honored (and no archive cleanup runs
    when opted out — Phase 0 is skipped along with everything else).
  - `archive/` subdirs are not swept by Phase 1.
  - Frontmatter without `status:` field never emits.
  - Frontmatter with `status: read` never emits.

- **Archive-retention unit test (same harness, dedicated case).**
  - Fixture: archive dir populated with one file mtime-backdated > 7
    days (`touch -t 202604100000` or equivalent `-mtime +7` satisfier
    on the test host) and one file with fresh mtime
    (default `touch`).
  - Run: `INBOX_WATCH_ONESHOT=1 bash scripts/hooks/inbox-watch.sh`. <!-- orianna: ok -->
  - Assert:
    - Stale file gone.
    - Fresh file present, bit-identical to pre-run state.
    - Empty month-bucket dir pruned; non-empty bucket retained.
    - Exit 0; stderr empty (no `find: permission denied` noise).
  - Edge: no `archive/` dir at all → Phase 0 silently no-ops (the
    `2>/dev/null` redirect absorbs the "no such file" error from
    `find`).

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

All v3 gating questions are closed (§8 and §10 v3 table). The next
step is `scripts/orianna-fact-check.sh` against this plan followed by
`scripts/plan-promote.sh proposed → approved`, which re-opens the
Orianna gate (Rule 19). A task-breakdown agent picks up execution
post-approval — plan writer does not assign.

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
| 1 | Nudge phrasing | `INBOX: <N> pending message(s) for <agent>. Run /check-inbox to read them.` | **Obsolete**: v3 emits per-message Monitor events, not a count. New line contract in v3 table Q3. |
| 2 | Opt-out filename | `.no-inbox-nudge` | **Renamed** to `.no-inbox-watch`; see v3 table Q5. |
| 3 | First-cut scope | Single commit | **Carried forward** to v3 table Q6. |
| 4 | Windows parity | Defer | **Carried forward** to v3 table Q4. |
| 5 | Regression guard | Yes, under `scripts/hooks/tests/` | **Carried forward and expanded** (watcher + archive-flow + retention). |

### v3 gating answers (approved by Duong 2026-04-21)

| # | Question (v3) | Answer | Where inlined |
|---|---|---|---|
| 1 | Read-flow disposition (archive vs. hard-delete) | **Archive** to `inbox/archive/<YYYY-MM>/` with `status: read` + `read_at`. **Additional requirement:** archived entries are auto-deleted after **7 days** (TTL enforced by the watcher's Phase 0 at session boot — see §3.2, §4.4). | §3.2 Phase 0, §3.4, §4.1, §4.4, §5 item 12 |
| 2 | Archive bucket granularity | **`YYYY-MM/`** month buckets. | §3.4 |
| 3 | Monitor event line format | **`INBOX: <filename> — from <sender> — <priority>`** (minimal three-field form). | §3.2 Line format block |
| 4 | Windows parity scope | **Defer.** POSIX-only for v3; PowerShell follow-up after v3 is green. | §7 |
| 5 | Opt-out filename | **`.no-inbox-watch`** at repo root. Total opt-out (suppresses cleanup *and* sweep *and* live watch). | §3.2 Opt-out block, §4.4 |
| 6 | Scope of first cut | **Single commit.** Watcher script + bootstrap script + skill recovery (with archive semantics) + `settings.json` wiring + unit harness ship as one interlocked deliverable. | §9 |
