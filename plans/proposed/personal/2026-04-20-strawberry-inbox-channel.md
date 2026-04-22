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
architecture_impact: none
tags: [inbox, coordinator, hooks, monitor]
---

# Strawberry inbox watcher — Monitor-based autonomous coordinator inbox delivery

ADR for surfacing `agents/<coordinator>/inbox/` messages inside running <!-- orianna: ok -- template or prospective path -->
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
  retention policy added — `inbox/archive/**` entries older than 7 days <!-- orianna: ok -- template or prospective path -->
  are deleted on next watcher boot (cleanup runs once per session, at
  the top of `inbox-watch.sh`, before the initial pending sweep). §8 <!-- orianna: ok -- prospective path or non-file token -->
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
`code.claude.com/docs/en/tools-reference#monitor-tool`) is the primitive <!-- orianna: ok -- template or prospective path -->
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
`agents/<coordinator>/inbox/` forever. That was tolerable when the nudge <!-- orianna: ok -- template or prospective path -->
was pull-based (`/check-inbox` filtered by `status: pending` anyway), but
is **fatal for a real-time watcher**:

- The watcher's initial sweep on boot would re-emit every already-read
  message from months ago.
- Filter discipline on the watcher side becomes brittle — we'd rely on
  `grep status: pending` against a growing pile of `status: read` files.
- The inbox directory becomes un-browsable for humans over time.

v3 makes the lifecycle explicit and enforced: the main `inbox/` directory <!-- orianna: ok -- template or prospective path -->
is a **pending-only** working set. `/check-inbox` moves each displayed
message to `inbox/archive/YYYY-MM/` with `status: read` and a `read_at` <!-- orianna: ok -- template or prospective path -->
timestamp. `/agent-ops send` writes to `inbox/` (flat). The watcher only <!-- orianna: ok -- template or prospective path -->
ever sees pending files.

## 1. Problem (unchanged in substance)

- Duong runs two top-level coordinators in parallel: Evelynn (personal) and
  Sona (work). They message each other via `/agent-ops send <agent> <msg>`,
  which writes `agents/<agent>/inbox/<ts>-<shortid>.md` with YAML <!-- orianna: ok -- template or prospective path -->
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
  `hookSpecificOutput.additionalContext` that the model acts on in its <!-- orianna: ok -- template or prospective path -->
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
| `SessionStart` hook (`additionalContext` only) | **Bootstrap.** Detects coordinator identity; if inbox exists, injects context instructing the coordinator to invoke `Monitor` on its first turn with `bash scripts/hooks/inbox-watch.sh` as the target script. | <!-- orianna: ok -- prospective path or non-file token -->
| `scripts/hooks/inbox-watch.sh` | **Watcher.** POSIX-portable script the Monitor runs. Emits one stdout line per `status: pending` message — at boot (initial sweep) and on each create/move-in event. Runs for session lifetime. | <!-- orianna: ok -- prospective path or non-file token -->
| `.claude/skills/check-inbox/SKILL.md` | **Reader + archiver.** Recovered from fb1bd4f and extended. Displays each pending message, then **moves** it to `inbox/archive/YYYY-MM/` with `status: read` + `read_at` set in frontmatter. Enforces the pending-only invariant of the main inbox dir. | <!-- orianna: ok -- prospective path or non-file token -->

No plugin, no MCP, no channels, no `--dangerously` flag, no daemon. Every
piece is either already supported today or is a POSIX shell script.

### 2.1 Why a hook "nudges" the coordinator to invoke Monitor rather than starting it directly

Hooks cannot invoke tools. The Monitor tool is invoked by the model.
`SessionStart.additionalContext` is the only hook surface that can <!-- orianna: ok -- template or prospective path -->
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

<!-- orianna: ok -- prospective path or non-file token --> `.claude/skills/check-inbox/SKILL.md` — prospective (to be recovered from fb1bd4f)
<!-- orianna: ok -- prospective path or non-file token --> `scripts/hooks/inbox-watch.sh` — prospective (new deliverable)
<!-- orianna: ok -- prospective path or non-file token --> `scripts/hooks/tests/inbox-watch-test.sh` — prospective (new unit harness)

v2's `scripts/hooks/inbox-nudge.sh` is **not created**. <!-- orianna: ok -- prospective path or non-file token --> The
`UserPromptSubmit` hook described in v2 is **not wired**. The
`SessionStart` hook continues to host resume-suppression logic, and we
add one additional `SessionStart` entry for the watcher bootstrap.

### 3.2 The watcher script — `scripts/hooks/inbox-watch.sh` <!-- orianna: ok -- prospective path or non-file token -->

POSIX-portable bash (Rule 10 compliance). Three phases, run in order:

**Phase 0: archive cleanup (one-shot, per session boot).** Runs once at
script start, before any emission. Deletes files in
`agents/<coordinator>/inbox/archive/**` whose mtime is older than 7 <!-- orianna: ok -- template or prospective path -->
days, then prunes empty month-bucket directories:

```sh
find "agents/${coord}/inbox/archive" -type f -name '*.md' -mtime +7 -delete 2>/dev/null
find "agents/${coord}/inbox/archive" -type d -empty -delete 2>/dev/null
```

`-mtime +7` is POSIX-defined as "more than 7 full 24-hour periods ago"
relative to the file's mtime — a well-defined wall-clock rule that does
not drift on DST transitions. The `2>/dev/null` suppresses noise when <!-- orianna: ok -- template or prospective path -->
the archive dir does not exist yet (fresh coordinator, first boot). If
the watcher never boots for > 7 days (e.g. coordinator offline for a
long trip), cleanup simply runs later on the next boot: no data loss,
slight retention overshoot. This behaviour is deliberate — we do not
add a cron, a systemd timer, or a scheduled skill; the watcher is the
sole enforcer of the retention TTL and it only runs when the
coordinator is live. See §4.4 for the retention model.

**Phase 1: boot-time pending sweep.** Runs once after Phase 0. Lists
`agents/<coordinator>/inbox/*.md` (top-level only — `archive/` is <!-- orianna: ok -- template or prospective path -->
excluded by pattern, since month-bucket subdirs are not matched by a
flat glob). For each file with `status: pending` in frontmatter, emit
one stdout line. This covers messages that landed while the session was
down.

**Phase 2: live watch.** After the sweep, monitor the same directory
(non-recursive) for new files. Detection order:

1. `fswatch` if present (macOS default once Homebrew-installed):
   `fswatch -x --event Created --event MovedTo agents/<coord>/inbox/`. <!-- orianna: ok -- template or prospective path -->
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
2. On `source=startup`, emits `hookSpecificOutput.additionalContext` <!-- orianna: ok -- template or prospective path -->
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
`YYYY-MM/` (settled §10 v3 table Q2). <!-- orianna: ok -- template or prospective path -->

Recover `.claude/skills/check-inbox/SKILL.md` from `fb1bd4f`, then <!-- orianna: ok -- prospective path or non-file token -->
rewrite the disposition step. New behaviour:

For each file matching `agents/<coord>/inbox/*.md` with `status: <!-- orianna: ok -- template or prospective path -->
pending`:

1. Read the message, display it to the coordinator (frontmatter +
   body).
2. Rewrite the frontmatter in place: `status: read`, add
   `read_at: <ISO-8601 UTC>`.
3. Compute the archive path: `agents/<coord>/inbox/archive/<YYYY-MM>/
   <original-filename>` where `<YYYY-MM>` is derived from the file's
   `timestamp:` frontmatter field (fallback: file mtime).
4. `mkdir -p` the month-bucket, then `mv` the file into it.
5. After processing all files, the main `inbox/` directory contains <!-- orianna: ok -- template or prospective path -->
   zero `status: pending` files (the post-condition).

**Identity resolution:** same three-way fallback as the watcher.

**Concurrency:** if two sessions run `/check-inbox` against the same
inbox (shouldn't happen in practice — Evelynn and Sona have separate
inboxes), the second `mv` fails because the source is gone; we skip
and continue. Idempotent.

**Why month buckets.** `YYYY-MM/` is the right granularity for a human <!-- orianna: ok -- template or prospective path -->
scanning the archive a month later (`ls inbox/archive/2026-04/` <!-- orianna: ok -- template or prospective path -->
immediately answers "what did I get in April?"). Year buckets
(`YYYY/`) accumulate too fast; day buckets (`YYYY-MM-DD/`) fragment <!-- orianna: ok -- template or prospective path -->
too much. Month also matches how Duong already organizes transcripts
(daily → month folder on archive). The 7-day retention (§4.4) means
each bucket typically holds at most one month's trailing week of read
messages — small enough that `mv` and `find` stay O(ms).

### 3.5 `.claude/settings.json` wiring

Append one hook entry under `SessionStart.hooks` (as a sibling of the <!-- orianna: ok -- template or prospective path -->
existing resume-suppression entry):

```json
{
  "type": "command",
  "command": "bash scripts/hooks/inbox-watch-bootstrap.sh"
}
```

<!-- orianna: ok -- prospective path or non-file token --> `scripts/hooks/inbox-watch-bootstrap.sh` — prospective (new deliverable, §3.5)

`inbox-watch-bootstrap.sh` is a tiny wrapper (can be inlined as a jq <!-- orianna: ok -- prospective path or non-file token -->
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
identity fallback. No `--channels` / `--dangerously-load-development- <!-- orianna: ok -- template or prospective path -->
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

Invariant: the top level of `agents/<coord>/inbox/` contains **only** <!-- orianna: ok -- template or prospective path -->
`status: pending` files. `archive/` contains **only** `status: read` <!-- orianna: ok -- template or prospective path -->
files. `/agent-ops send` always writes to `inbox/` (flat, never <!-- orianna: ok -- template or prospective path -->
`archive/`). `/check-inbox` is the only writer of `archive/`. The <!-- orianna: ok -- template or prospective path -->
watcher's Phase 0 is the only **deleter** of `archive/` entries (see <!-- orianna: ok -- template or prospective path -->
§4.4).

### 4.2 Timing

- **Boot-time latency** (message arrived before session start →
  coordinator sees it): one initial sweep inside Phase 1 of the
  watcher. Bounded by the time for the coordinator's first Monitor
  invocation (which is the first tool call after reading the
  `SessionStart` nudge). Target ≤ 5 s end-to-end.
- **Live latency** (message arrives mid-session):
  - `fswatch` / `inotifywait` path: sub-second — these are kernel-level <!-- orianna: ok -- template or prospective path -->
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

### 4.4 Retention — 7-day TTL on `inbox/archive/**` <!-- orianna: ok -- template or prospective path -->

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
- **No retention on the pending set**: `inbox/*.md` (pending messages) <!-- orianna: ok -- template or prospective path -->
  are not subject to any TTL. A message that was never read sits until
  `/check-inbox` moves it. That is the correct semantic — we must not
  silently drop unread mail.

## 5. Acceptance criteria

All criteria empirically testable against a live session.

1. **Boot-time message surfaces within one turn.**
   - Setup: one `status: pending` file in `agents/evelynn/inbox/`; <!-- orianna: ok -- template or prospective path -->
     `agents/evelynn/inbox/archive/` empty or populated with read <!-- orianna: ok -- template or prospective path -->
     messages.
   - Action: launch `evelynn`. Observe the model's first turn.
   - Expected: the model's first turn invokes `Monitor` with
     `bash scripts/hooks/inbox-watch.sh`. Within a few seconds of <!-- orianna: ok -- prospective path or non-file token -->
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
     (a) `agents/evelynn/inbox/` contains zero `status: pending` <!-- orianna: ok -- template or prospective path -->
         files (it may contain the `archive/` subdir; nothing else). <!-- orianna: ok -- template or prospective path -->
     (b) Each previously-pending file is now under
         `agents/evelynn/inbox/archive/<YYYY-MM>/` with <!-- orianna: ok -- template or prospective path -->
         `status: read` and a `read_at` ISO-8601 UTC timestamp.
     (c) Monitor did not emit a duplicate `INBOX:` event triggered by
         the frontmatter rewrite (filter discipline).

4. **`/agent-ops send` writes to `inbox/`, never `archive/`.** <!-- orianna: ok -- template or prospective path -->
   - Grep / code-read check: `.claude/skills/agent-ops/SKILL.md` §`send`
     writes to `agents/<to>/inbox/<name>.md` only. No reference to <!-- orianna: ok -- template or prospective path -->
     `archive/` in the send path. <!-- orianna: ok -- template or prospective path -->

5. **Resume / clear / compact does not re-bootstrap.**
   - Setup: running session, Monitor already active.
   - Action: `/compact`; session resumes.
   - Expected: no additional "invoke Monitor" nudge in the resumed
     turn. The previous Monitor is gone; coordinator may restart it
     manually if desired. No INBOX: spam on resume.

6. **No-identity short-circuit.** Invoke bootstrap and watcher
   directly with no identity env vars and `agent` stripped from
   `settings.json`. Expected: both exit 0, empty stdout. <!-- orianna: ok -- template or prospective path -->

7. **Unknown-agent short-circuit.** Invoke with
   `CLAUDE_AGENT_NAME=nonexistent` and no such directory. Expected:
   exit 0, empty stdout.

8. **Opt-out honored.** `touch .no-inbox-watch`; rerun. Expected:
   bootstrap script and watcher both exit 0 silently.

9. **No Channels / MCP / dev-flag regressions.**
   - `grep -r "strawberry-inbox" .claude/plugins` → no matches. <!-- orianna: ok -- template or prospective path -->
   - `grep -r "channelsEnabled\|--channels\|development-channels"
     scripts .claude` → no matches.
   - `find . -name ".mcp.json" -path "*/strawberry-inbox/*"` → no <!-- orianna: ok -- template or prospective path -->
     matches.

10. **No v2 nudge regressions.**
    - `.claude/settings.json` has no `UserPromptSubmit` entry
      referencing `inbox-nudge` or `inbox-watch`.
    - `scripts/hooks/` does not contain `inbox-nudge.sh`. <!-- orianna: ok -- prospective path or non-file token -->
    - No `additionalContext` string anywhere in `scripts/hooks/` <!-- orianna: ok -- template or prospective path -->
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
      `agents/<coord>/inbox/archive/2026-03/old-msg.md` with mtime <!-- orianna: ok -- template or prospective path -->
      backdated to 10 days ago (e.g. `touch -t` or
      `-d '10 days ago'`), and
      `agents/<coord>/inbox/archive/2026-04/fresh-msg.md` with mtime <!-- orianna: ok -- template or prospective path -->
      within the last 24 h.
    - Action: run `scripts/hooks/inbox-watch.sh` with <!-- orianna: ok -- prospective path or non-file token -->
      `INBOX_WATCH_ONESHOT=1` (runs Phase 0 then Phase 1).
    - Expected:
      (a) `old-msg.md` is deleted. <!-- orianna: ok -- template or prospective path -->
      (b) `fresh-msg.md` remains. <!-- orianna: ok -- template or prospective path -->
      (c) If `archive/2026-03/` is now empty, the directory itself is <!-- orianna: ok -- template or prospective path -->
          also pruned; `archive/2026-04/` survives because it still <!-- orianna: ok -- template or prospective path -->
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
  watches its own `agents/<name>/inbox/`. No cross-interference. <!-- orianna: ok -- template or prospective path -->
- **Archive dir accidentally watched.** The watcher's glob is flat
  (`inbox/*.md`), not recursive. `archive/` subdirs are not watched. <!-- orianna: ok -- template or prospective path -->
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
- Windows parity — `scripts/hooks/inbox-watch.sh` will be POSIX, but <!-- orianna: ok -- prospective path or non-file token -->
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

- **Unit-level (`scripts/hooks/tests/inbox-watch-test.sh`).** <!-- orianna: ok -- prospective path or non-file token -->
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
  - `archive/` subdirs are not swept by Phase 1. <!-- orianna: ok -- template or prospective path -->
  - Frontmatter without `status:` field never emits.
  - Frontmatter with `status: read` never emits.

- **Archive-retention unit test (same harness, dedicated case).**
  - Fixture: archive dir populated with one file mtime-backdated > 7
    days (`touch -t 202604100000` or equivalent `-mtime +7` satisfier
    on the test host) and one file with fresh mtime
    (default `touch`).
  - Run: `INBOX_WATCH_ONESHOT=1 bash scripts/hooks/inbox-watch.sh`. <!-- orianna: ok -- prospective path or non-file token -->
  - Assert:
    - Stale file gone.
    - Fresh file present, bit-identical to pre-run state.
    - Empty month-bucket dir pruned; non-empty bucket retained.
    - Exit 0; stderr empty (no `find: permission denied` noise).
  - Edge: no `archive/` dir at all → Phase 0 silently no-ops (the <!-- orianna: ok -- template or prospective path -->
    `2>/dev/null` redirect absorbs the "no such file" error from <!-- orianna: ok -- template or prospective path -->
    `find`).

- **`/check-inbox` archive-flow test (same harness, separate case).**
  - Create a pending file with a known `timestamp:` (say
    `2026-04-21T14:23:00Z`). Run the archive routine. Assert:
    - `agents/<coord>/inbox/` has zero `status: pending` files. <!-- orianna: ok -- template or prospective path -->
    - `agents/<coord>/inbox/archive/2026-04/<original-filename>` <!-- orianna: ok -- template or prospective path -->
      exists.
    - Archived file's frontmatter: `status: read`, `read_at:` is a
      valid ISO-8601 UTC string.
  - Edge: file with no `timestamp:` frontmatter — archive path falls
    back to mtime's `YYYY-MM`.

- **Regression floor (same harness).**
  - `grep -rn "strawberry-inbox" .claude/plugins` → no matches <!-- orianna: ok -- template or prospective path -->
    (directory absent).
  - `grep -rn "channelsEnabled\|--channels\|development-channels"
    scripts/ .claude/` → no matches.
  - `grep -rn "UserPromptSubmit" .claude/settings.json` does not name <!-- orianna: ok -- template or prospective path -->
    an inbox-nudge / inbox-watch command.
  - `scripts/hooks/inbox-nudge.sh` does not exist. <!-- orianna: ok -- prospective path or non-file token -->
  - No string `"pending message(s). Run /check-inbox to read them."` <!-- orianna: ok -- template or prospective path -->
    appears in `scripts/hooks/` (v2 phrasing fingerprint). <!-- orianna: ok -- template or prospective path -->

- **End-to-end empirical (manual, archived under
  `assessments/qa-reports/<date>-inbox-watch.md`).** Walk acceptance <!-- orianna: ok -- template or prospective path -->
  criteria §5 items 1, 2, 3, 5, 11 against a live Evelynn and a live
  Sona. Record wall-clock latency, exact Monitor event text, and
  final inbox + archive directory state. Failing criteria block
  promotion past in-progress.

- **No new CI jobs.** The unit harness plugs into the existing
  pre-commit hook test harness (`scripts/hooks/tests/`). <!-- orianna: ok -- template or prospective path -->

## 9. Handoff

All v3 gating questions are closed (§8 and §10 v3 table). The next
step is `scripts/orianna-fact-check.sh` against this plan followed by
`scripts/plan-promote.sh proposed → approved`, which re-opens the <!-- orianna: ok -- template or prospective path -->
Orianna gate (Rule 19). A task-breakdown agent picks up execution
post-approval — plan writer does not assign.

## 10. Prior gating answers and v3 status

### v1 gating answers (approved 2026-04-20, now mostly obsolete)

Preserved verbatim for audit trail.

| # | Question (v1) | v1 decision | v2 status | v3 status |
|---|---|---|---|---|
| 1 | Plugin location | `.claude/plugins/strawberry-inbox/` | Obsolete (no plugin) | Obsolete | <!-- orianna: ok -- template or prospective path -->
| 2 | Coordinator identification | `CLAUDE_AGENT_NAME`, fallback `STRAWBERRY_AGENT` | Carried + `.claude/settings.json .agent` fallback | **Carried forward (v2 chain)** | <!-- orianna: ok -- template or prospective path -->
| 3 | Auto-mark-read | Yes — flip `status: read` on display | Carried | **Superseded**: move to `archive/YYYY-MM/` with `status: read` + `read_at` | <!-- orianna: ok -- template or prospective path -->
| 4 | Skill name | `/check-inbox` | Carried | **Carried forward** |
| 5 | First-cut scope | Bundle plugin + skill as one deliverable | Restated as hook + skill | **Restated as Monitor watcher + bootstrap + skill + tests as one cut** |

### v2 gating proposals (superseded without being answered)

v2 was amended to v3 before Duong ruled on its gating questions.
For completeness:

| # | Question (v2) | v2 proposed default | v3 disposition |
|---|---|---|---|
| 1 | Nudge phrasing | `INBOX: <N> pending message(s) for <agent>. Run /check-inbox to read them.` | **Obsolete**: v3 emits per-message Monitor events, not a count. New line contract in v3 table Q3. | <!-- orianna: ok -- template or prospective path -->
| 2 | Opt-out filename | `.no-inbox-nudge` | **Renamed** to `.no-inbox-watch`; see v3 table Q5. |
| 3 | First-cut scope | Single commit | **Carried forward** to v3 table Q6. |
| 4 | Windows parity | Defer | **Carried forward** to v3 table Q4. |
| 5 | Regression guard | Yes, under `scripts/hooks/tests/` | **Carried forward and expanded** (watcher + archive-flow + retention). | <!-- orianna: ok -- template or prospective path -->

### v3 gating answers (approved by Duong 2026-04-21)

| # | Question (v3) | Answer | Where inlined |
|---|---|---|---|
| 1 | Read-flow disposition (archive vs. hard-delete) | **Archive** to `inbox/archive/<YYYY-MM>/` with `status: read` + `read_at`. **Additional requirement:** archived entries are auto-deleted after **7 days** (TTL enforced by the watcher's Phase 0 at session boot — see §3.2, §4.4). | §3.2 Phase 0, §3.4, §4.1, §4.4, §5 item 12 | <!-- orianna: ok -- template or prospective path -->
| 2 | Archive bucket granularity | **`YYYY-MM/`** month buckets. | §3.4 | <!-- orianna: ok -- template or prospective path -->
| 3 | Monitor event line format | **`INBOX: <filename> — from <sender> — <priority>`** (minimal three-field form). | §3.2 Line format block |
| 4 | Windows parity scope | **Defer.** POSIX-only for v3; PowerShell follow-up after v3 is green. | §7 |
| 5 | Opt-out filename | **`.no-inbox-watch`** at repo root. Total opt-out (suppresses cleanup *and* sweep *and* live watch). | §3.2 Opt-out block, §4.4 |
| 6 | Scope of first cut | **Single commit.** Watcher script + bootstrap script + skill recovery (with archive semantics) + `settings.json` wiring + unit harness ship as one interlocked deliverable. | §9 | <!-- orianna: ok -- template or prospective path -->

## Tasks

_Task breakdown authored by Aphelios._

Executable task list for this ADR (v3.1, Orianna-signed
`sha256:d5979ae9013e1af1748366f0f0b837047082730681eb35a9640b7abcbee90e4a:2026-04-21T03:59:37Z`).

Azir's ADR settles all six v3 gating questions (§10 v3 table). This
breakdown decomposes the approved design into **two commits on one
branch / one PR** — an xfail-test commit (Rakan) followed by an
implementation commit (Viktor) — honouring both the ADR's "single cut"
intent (§10 Q6) and Rule 12's TDD gate (xfail first).

### Scope boundary

This plan is **infrastructure-only**. Every file touched lives in
`~/Documents/Personal/strawberry-agents/` (this repo). **No <!-- orianna: ok -- template or prospective path -->
`apps/**` change**, so every commit uses `chore:` (CLAUDE.md Rule 5). <!-- orianna: ok -- template or prospective path -->
The deliverable makes the personal coordinator (Evelynn) observe the
inbox in real time and keeps the Sona-side wiring symmetric
(coordinator-identity resolution chain works for either agent out of
the same script).

### Duong-in-loop blockers

All v3 gating answers are decided (ADR §10 v3 table). **No Duong-blockers
remain**. The breakdown can start the moment this file lands on main.

Two soft assumptions the executors should verify on first read (not
blocking, but flag to Evelynn if either breaks):

| #            | Assumption                                                                                                   | Verify by                                                          |
|--------------|--------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| A-inbox-1    | Claude Code ≥ v2.1.98 on this machine (Monitor tool available).                                              | `claude --version` against ADR §1 "What *is* available" bullet 1.  |
| A-inbox-2    | `fb1bd4f` is still reachable from main (for recovering `/check-inbox`). Confirmed at breakdown time: yes.   | `git cat-file -e fb1bd4f:.claude/skills/check-inbox/SKILL.md`.     | <!-- orianna: ok -- template or prospective path -->

### Team composition

| Role                   | Agent  | Scope                                                                    |
|------------------------|--------|--------------------------------------------------------------------------|
| Test implementer       | Rakan  | Task IW.0 — xfail harness under `scripts/hooks/tests/`.                  | <!-- orianna: ok -- template or prospective path -->
| Complex-track builder  | Viktor | Tasks IW.1 – IW.5 — watcher, bootstrap, skill recovery, settings wiring. |
| Reviewer A             | Senna  | PR review — architecture + hook wiring.                                  |
| Reviewer B             | Lucian | PR review — shell-script correctness + POSIX portability + test harness. |

No executor overlap. Rakan ships IW.0 and hands the branch off; Viktor
picks it up for IW.1 – IW.5 and opens the PR.

### Task summary

**6 tasks total** on a single feature branch. One PR, two commits at
minimum (xfail + impl); additional fixup commits are fine as long as
the xfail-first ordering is preserved (Rule 12).

| #     | Task                                                                                    | kind   | estimate_minutes | Owner  | Commit slot | Depends on |
|-------|-----------------------------------------------------------------------------------------|--------|-----------------|--------|-------------|------------|
| IW.0  | Write xfail harness — watcher, skill archive flow, retention, regression floor          | test   | 30              | Rakan  | commit 1    | —          |
| IW.1  | `scripts/hooks/inbox-watch.sh` — watcher script (Phase 0/1/2 + oneshot)                |        | 45              | Viktor | commit 2    | IW.0       |
| IW.2  | `scripts/hooks/inbox-watch-bootstrap.sh` — SessionStart nudge emitter                  |        | 45              | Viktor | commit 2    | IW.0       |
| IW.3  | `.claude/skills/check-inbox/SKILL.md` — recover from `fb1bd4f` + archive               |        | 45              | Viktor | commit 2    | IW.0       |
| IW.4  | `.claude/settings.json` — append SessionStart entry for bootstrap                      |        | 45              | Viktor | commit 2    | IW.1–IW.3  |
| IW.5  | Flip `scripts/hooks/tests/inbox-watch-test.sh` green + regression grep                 |        | 30              | Viktor | commit 2    | IW.1–IW.4  |

**Xfail-first ordering (Rule 12):** IW.0 MUST be the first commit on
the branch. IW.1 – IW.5 land in a second commit (or squash-amenable
series of fixups) that flips the harness green.

**Parallel window:** inside IW.1 – IW.5 the tasks are sequential by
dependency (watcher → bootstrap → skill → settings → green). No
intra-phase parallelism; a single Viktor session runs them in order.

### Branch, PR, commits

- **Branch name:** `inbox-watch-v3`
- **Created via:** `scripts/safe-checkout.sh inbox-watch-v3` (Rule 3 — <!-- orianna: ok -- template or prospective path -->
  never raw `git checkout`).
- **Base:** `main` at the SHA on which this breakdown is committed.
- **Commit prefix:** `chore:` on all commits (Rule 5 — no `apps/**`). <!-- orianna: ok -- template or prospective path -->
- **Do NOT** `--no-verify`, `--no-gpg-sign`, or skip hooks (Rule 14).
- **Do NOT** rebase (Rule 11) — if branch drifts behind main, merge.
- **PR target:** `harukainguyen1411/strawberry-agents` `main` <!-- orianna: ok -- template or prospective path -->
  (`gh pr create --base main --head inbox-watch-v3`).

#### PR shell (for Viktor to paste, verbatim body)

```
gh pr create --base main --head inbox-watch-v3 \
  --title "chore: strawberry inbox watcher — Monitor-driven real-time inbox delivery" \
  --reviewer Duongntd \
  --body "$(cat <<'EOF'
## Summary
- Ship `scripts/hooks/inbox-watch.sh` — POSIX-portable Monitor target; Phase 0 archive cleanup, Phase 1 boot sweep, Phase 2 live watch (fswatch → inotifywait → 3 s poll).
- Ship `scripts/hooks/inbox-watch-bootstrap.sh` — SessionStart `additionalContext` nudge, resume/clear/compact short-circuit, `.no-inbox-watch` opt-out. <!-- orianna: ok -- template or prospective path -->
- Recover `.claude/skills/check-inbox/SKILL.md` from `fb1bd4f` and extend with archive-to-`inbox/archive/YYYY-MM/` semantics + `read_at` frontmatter. <!-- orianna: ok -- template or prospective path -->
- Append one `SessionStart` entry to `.claude/settings.json`.

Implements `plans/in-progress/2026-04-20-strawberry-inbox-channel.md` <!-- orianna: ok -- template or prospective path -->
(v3.1; Orianna signature `sha256:d5979…:2026-04-21T03:59:37Z`).

## Test plan
- [ ] `bash scripts/hooks/tests/inbox-watch-test.sh` exits 0 (watcher sweep + archive + retention + regression cases). <!-- orianna: ok -- template or prospective path -->
- [ ] Acceptance §5 items 1, 2, 3, 5, 11 pass against a live Evelynn session (manual; report → `assessments/qa-reports/2026-04-…-inbox-watch.md`). <!-- orianna: ok -- template or prospective path -->
- [ ] `grep -rn "strawberry-inbox" .claude/plugins` → no matches. <!-- orianna: ok -- template or prospective path -->
- [ ] `grep -rn 'channelsEnabled\|--channels\|development-channels' scripts .claude` → no matches.
- [ ] `scripts/hooks/inbox-nudge.sh` does not exist. <!-- orianna: ok -- template or prospective path -->
- [ ] Pre-push TDD gate green (xfail commit precedes impl commit on branch).

Reviewers: @Senna (architecture) + @Lucian (shell + POSIX).
EOF
)"
```

- **Merge policy:** Rule 18 — Viktor does NOT merge his own PR. Senna
  and Lucian review. Duong or another approver with write merges once
  CI is green and both reviewers have approved.

---

### IW.0 — Write xfail harness (Rakan)

**Repo:** `strawberry-agents`
**Commit slot:** commit 1 (xfail, first on branch)
**ADR refs:** §5 (acceptance items 1–12), "Test plan" section,
§3.2 (Phase 0/1/2), §3.4 (check-inbox archive flow).

**What:** Create the unit harness **before any implementation
exists**, so it fails loudly (xfail) and the pre-push TDD gate is
satisfied (Rule 12). The harness is a POSIX bash script that sets up
fixture directories under `$(mktemp -d)`, invokes the (not-yet-existing)
scripts, and asserts on stdout lines and on-disk state.

**Files touched (NEW):** <!-- orianna: ok -- prospective path or non-file token -->
- `scripts/hooks/tests/inbox-watch-test.sh` — main harness, xfail-gated.

**Acceptance (xfail semantics):**
- Script is executable (`chmod +x`) and starts with `#!/usr/bin/env bash` <!-- orianna: ok -- template or prospective path -->
  + `set -euo pipefail`.
- Top of file: `# xfail: implements plans/in-progress/2026-04-20-strawberry-inbox-channel.md` comment. <!-- orianna: ok -- template or prospective path -->
- Script defines one test per §5 item it covers, each as a bash
  function (`test_boot_sweep_emits_one_line_per_pending`,
  `test_line_format_contract`, `test_identity_resolution_chain`,
  `test_no_inbox_watch_opt_out_short_circuits`,
  `test_archive_subdir_not_swept`,
  `test_frontmatter_without_status_never_emits`,
  `test_status_read_never_emits`,
  `test_archive_retention_deletes_files_older_than_7_days`,
  `test_archive_retention_prunes_empty_month_buckets`,
  `test_archive_retention_preserves_fresh_files`,
  `test_archive_cleanup_noop_when_archive_dir_absent`,
  `test_check_inbox_moves_pending_to_archive_yyyy_mm`,
  `test_check_inbox_archive_fallback_to_mtime_when_no_timestamp`,
  `test_regression_no_channels_artifacts`,
  `test_regression_no_inbox_nudge_sh`,
  `test_regression_no_user_prompt_submit_inbox_entry`,
  `test_regression_no_v2_nudge_phrasing`).
- All test functions marked xfail by bracketing each body in
  `if ! { <real assertion>; }; then printf 'XFAIL: %s\n' "$FUNCNAME"; return 0; fi; printf 'XPASS (unexpected): %s\n' "$FUNCNAME"; return 1`
  — so the harness **passes** today (every test xfails as expected)
  and flips to a real PASS once Viktor lands the implementation.
  Viktor will strip the xfail wrapper in IW.5.
- Harness exits 0 when every test xfails as expected, non-zero if any
  test unexpectedly passes (which will only happen once implementation
  lands — that's the flip point for IW.5).
- Fixtures:
  - `fixture/inbox-empty/` — empty inbox, archive absent. <!-- orianna: ok -- template or prospective path -->
  - `fixture/inbox-one-pending/` — single `status: pending` file with <!-- orianna: ok -- template or prospective path -->
    `timestamp: 2026-04-21T14:23:00Z`, `from: sona`, `priority: high`.
  - `fixture/inbox-mixed/` — one pending + one file with <!-- orianna: ok -- template or prospective path -->
    `status: read` (must not be emitted); `archive/2026-03/stale.md` <!-- orianna: ok -- template or prospective path -->
    with mtime backdated 10 days (`touch -t 202604110000` or
    `touch -d '10 days ago'`; use the POSIX `-t` form with a
    date that is unambiguously > 7 days before today's
    `date +%Y%m%d%H%M`).
  - `fixture/inbox-no-identity/` — no `CLAUDE_AGENT_NAME`, <!-- orianna: ok -- template or prospective path -->
    no `STRAWBERRY_AGENT`, stripped `.agent` — assert exit 0 +
    empty stdout.
  - `fixture/inbox-opt-out/` — `.no-inbox-watch` sentinel present at <!-- orianna: ok -- template or prospective path -->
    the fake repo root; assert Phase 0 does NOT run (place a stale
    archived file and verify it survives).
- Line-format assertion uses the regex from the ADR §3.2 contract:
  `^INBOX: [^ ]+\.md — from [^ ]+ — [a-z]+$` (em-dash `—`, U+2014 —
  **not** a hyphen). Harness must match bytes, not just visually.
- `INBOX_WATCH_ONESHOT=1` is set for every watcher invocation inside
  the harness (Phase 0 + Phase 1 only; no Phase 2 live-watch path is
  exercised in unit tests — that's manual acceptance §5 item 2).
- Regression greps are plain `grep -rn` invocations wrapped in
  assertions (`! grep -rn …` ⇒ expected to exit 1).

**DoD:**
- `bash scripts/hooks/tests/inbox-watch-test.sh` exits **0** on a <!-- orianna: ok -- template or prospective path -->
  clean checkout where `inbox-watch.sh` does NOT yet exist — because <!-- orianna: ok -- template or prospective path -->
  every test xfails as expected. This is the Rule-12 xfail commit's
  green signal.
- Pre-push hook accepts the commit (xfail commit references plan path
  in the header comment — `pre-push-tdd.sh` matches on <!-- orianna: ok -- template or prospective path -->
  `plans/in-progress/2026-04-20-strawberry-inbox-channel`). <!-- orianna: ok -- template or prospective path -->

**Commit message:**
```
chore: xfail harness for inbox watcher — pre-impl

Adds scripts/hooks/tests/inbox-watch-test.sh with the full test
matrix (watcher sweep, line format, identity chain, opt-out,
archive flow, 7-day retention, regression greps) guarded as xfail.
Flip to green in the follow-up impl commit.

Refs plans/in-progress/2026-04-20-strawberry-inbox-channel.md.
```

**Blockers:** none.
**Depends on:** — (first commit on branch).
**Hand-off:** Rakan pushes commit 1 to `inbox-watch-v3`, then posts a
line to `agents/viktor/inbox/` (via `/agent-ops send viktor …`) <!-- orianna: ok -- template or prospective path -->
notifying of branch readiness.

---

### IW.1 — Watcher script (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.2 (Phase 0/1/2), §4.2 (timing), §4.4 (retention),
§3.6 (launcher), §5 items 1, 6, 7, 8, 11, 12.

**What:** Implement `scripts/hooks/inbox-watch.sh` per ADR §3.2,
verbatim phase order: Phase 0 (archive cleanup) → Phase 1 (pending
sweep) → Phase 2 (live watch). POSIX-portable (Rule 10).

**Files touched (NEW):** <!-- orianna: ok -- prospective path or non-file token -->
- `scripts/hooks/inbox-watch.sh`

**Implementation anchors (map each to the ADR):**

| Anchor                                                           | ADR location                   |
|------------------------------------------------------------------|--------------------------------|
| `#!/usr/bin/env bash` + `set -eu` (no pipefail in POSIX dash)    | Rule 10; ADR §3.2 "POSIX-portable bash" | <!-- orianna: ok -- template or prospective path -->
| Coordinator-identity chain: env → `.claude/settings.json .agent` | §3.2 "Coordinator identity resolution" | <!-- orianna: ok -- template or prospective path -->
| `.no-inbox-watch` check **before Phase 0**                       | §3.2 "Opt-out"; §4.4 "Opt-out interaction" |
| Phase 0 `find … -mtime +7 -delete` then empty-dir prune          | §3.2 Phase 0 block; §4.4       |
| Phase 0 stderr-suppress missing-archive case                     | §3.2 "The `2>/dev/null` suppresses noise" | <!-- orianna: ok -- template or prospective path -->
| Phase 1 flat glob on `inbox/*.md` (archive excluded by shape)    | §3.2 Phase 1                   | <!-- orianna: ok -- template or prospective path -->
| Per-file filter: only emit when `status: pending`                | §3.2 Phase 1 + Phase 2         |
| Line format: `INBOX: <filename> — from <sender> — <priority>`    | §3.2 Line format block, §10 v3 Q3 |
| Phase 2 detection order: fswatch → inotifywait → poll (3 s)      | §3.2 Phase 2                   |
| `INBOX_WATCH_ONESHOT=1` runs Phase 0 + Phase 1 only, then exits  | §3.2 "One-shot mode"           |
| No internal restart loop on `fswatch`/`inotifywait` exit         | §3.2 "Lifecycle"               |
| No extra stdout output beyond `INBOX:` lines (noisy-monitor risk) | §6 "Noisy-monitor auto-kill"  |

**Acceptance:**
- Running against `fixture/inbox-empty/` with `INBOX_WATCH_ONESHOT=1` <!-- orianna: ok -- template or prospective path -->
  prints nothing and exits 0.
- Running against `fixture/inbox-one-pending/` prints **exactly one <!-- orianna: ok -- template or prospective path -->
  line** matching the line-format regex.
- Running against `fixture/inbox-mixed/` prints exactly one line <!-- orianna: ok -- template or prospective path -->
  (pending only; `status: read` suppressed); stale archive file
  is deleted; fresh archive file survives; empty month-bucket dir
  pruned; non-empty bucket retained.
- `.no-inbox-watch` present → exit 0 immediately; stale archive file
  **survives** (Phase 0 did NOT run).
- No coordinator identity resolvable → exit 0, empty stdout.
- `CLAUDE_AGENT_NAME=nonexistent` + no such agent dir → exit 0, empty
  stdout.
- Script has **no** `set -x`, no `echo "debug: …"`, no stray lines on
  stdout other than `INBOX:` events.

**DoD:**
- Harness from IW.0 passes all watcher-case tests (xfail → XPASS is
  the signal; Viktor strips the xfail wrapper in IW.5 once every
  script is in place).
- `shellcheck scripts/hooks/inbox-watch.sh` clean (SC2086 tolerated <!-- orianna: ok -- template or prospective path -->
  only where POSIX word-splitting is intentional; document with
  inline `# shellcheck disable=…` + reason).
- Script is executable (`chmod +x`).

**Blockers:** none.
**Depends on:** IW.0 (harness must exist to verify).

---

### IW.2 — Bootstrap hook (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.3, §3.5, §5 items 5, 6, 8.

**What:** Implement
`scripts/hooks/inbox-watch-bootstrap.sh` — the SessionStart hook
target that emits `hookSpecificOutput.additionalContext` instructing <!-- orianna: ok -- template or prospective path -->
the coordinator to invoke `Monitor` on its first turn.

**Files touched (NEW):** <!-- orianna: ok -- prospective path or non-file token -->
- `scripts/hooks/inbox-watch-bootstrap.sh`

**Implementation anchors:**

| Anchor                                                                                        | ADR location   |
|-----------------------------------------------------------------------------------------------|----------------|
| Read stdin JSON; if `.source != "startup"` exit 0 silently                                     | §3.5 bullet 1  |
| `source ∈ {resume, clear, compact}` → no re-bootstrap (delegated to existing hook + this one) | §3.3 paragraph 1, §6 "Session compact" |
| Identity chain (same three sources as watcher)                                                 | §3.3 bullet 3, §3.5 |
| `.no-inbox-watch` → exit 0                                                                     | §3.5 bullet 3  |
| Emit single JSON object with `hookSpecificOutput.hookEventName=SessionStart` + `additionalContext` | §3.3 bullet 2, §3.5 bullet 4 |
| `additionalContext` text matches the ADR §3.3 template (verbatim: `INBOX WATCHER: invoke the Monitor tool on your first action with: / command: bash scripts/hooks/inbox-watch.sh / description: Watch <agent>'s inbox for new messages. / Events will surface as INBOX: … notifications. When you see one, run /check-inbox to read and archive the message.`) | §3.3 bullet 2 | <!-- orianna: ok -- template or prospective path -->

**Acceptance:**
- `echo '{"source":"startup"}' | CLAUDE_AGENT_NAME=evelynn bash
  scripts/hooks/inbox-watch-bootstrap.sh` prints valid JSON with
  `hookSpecificOutput.additionalContext` containing the substring <!-- orianna: ok -- template or prospective path -->
  `invoke the Monitor tool` AND `bash scripts/hooks/inbox-watch.sh` <!-- orianna: ok -- template or prospective path -->
  AND the agent name `evelynn` (lowercased).
- `echo '{"source":"resume"}' | …` → exit 0, empty stdout.
- `echo '{"source":"clear"}' | …` → exit 0, empty stdout.
- `echo '{"source":"compact"}' | …` → exit 0, empty stdout.
- `echo '{"source":"startup"}' | …` (no identity) → exit 0, empty
  stdout.
- `.no-inbox-watch` present → exit 0, empty stdout regardless of
  source.
- `jq -e .` validates the emitted JSON.

**DoD:** harness bootstrap cases flip from XFAIL → XPASS.
**Blockers:** none.
**Depends on:** IW.0.

---

### IW.3 — `/check-inbox` skill — recover + archive semantics (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.4, §4.1, §5 items 3, 4, 11.

**What:** Recover `.claude/skills/check-inbox/SKILL.md` from commit
`fb1bd4f` (`git show fb1bd4f:.claude/skills/check-inbox/SKILL.md`), <!-- orianna: ok -- template or prospective path -->
then rewrite the disposition step to **archive** read messages under
`inbox/archive/<YYYY-MM>/` with `status: read` + `read_at:` — NOT the <!-- orianna: ok -- template or prospective path -->
v1 in-place status flip.

**Files touched (NEW — recovered):** <!-- orianna: ok -- prospective path or non-file token -->
- `.claude/skills/check-inbox/SKILL.md`

**Implementation anchors:**

| Anchor                                                                                | ADR location |
|---------------------------------------------------------------------------------------|--------------|
| Recovery source: `git show fb1bd4f:.claude/skills/check-inbox/SKILL.md`               | §3.4 "Recover … from `fb1bd4f`" | <!-- orianna: ok -- template or prospective path -->
| Identity resolution: same three-way chain                                              | §3.4 "Identity resolution" |
| Per-pending-file flow: display → rewrite frontmatter → mkdir bucket → mv               | §3.4 bullets 1–4 |
| YYYY-MM derived from `timestamp:` frontmatter                                          | §3.4 bullet 3 |
| Fallback to file mtime when `timestamp:` absent                                        | §3.4 bullet 3 + §6 "Frontmatter without `timestamp:`" |
| Concurrency: `mv` fails when source gone → skip & continue (no abort)                  | §3.4 "Concurrency" |
| Post-condition: `inbox/` has zero `status: pending` files                              | §3.4 bullet 5, §5 item 3(a) | <!-- orianna: ok -- template or prospective path -->
| `read_at` is ISO-8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`)                              | §3.4 bullet 2, §5 item 3(b) |

**Acceptance:**
- Given a fixture inbox with one pending message whose frontmatter
  has `timestamp: 2026-04-21T14:23:00Z`, running `/check-inbox` (via
  the harness which exercises the skill's documented steps as a
  shell equivalent) yields:
  - `inbox/` contains zero `status: pending` files. <!-- orianna: ok -- template or prospective path -->
  - `inbox/archive/2026-04/<original-filename>` exists. <!-- orianna: ok -- template or prospective path -->
  - Archived file has `status: read` and `read_at:` matching the
    regex `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$`.
- Given a fixture message with **no** `timestamp:` field but with
  mtime in April 2026, the archive path lands in `2026-04/` (mtime <!-- orianna: ok -- template or prospective path -->
  fallback).
- During the rewrite, the brief `status: pending → read` edit does
  **not** trigger a second `INBOX:` emission from a running watcher
  (covered by the harness's "filter discipline" case; skill must
  write the `read` status **before** the `mv` so a watcher racing
  the move sees `status: read`).

**DoD:** harness skill-archive cases flip from XFAIL → XPASS.
**Blockers:** none.
**Depends on:** IW.0.

---

### IW.4 — `.claude/settings.json` wiring (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.5, §5 item 10.

**What:** Append a second `SessionStart.hooks` entry that runs <!-- orianna: ok -- template or prospective path -->
`scripts/hooks/inbox-watch-bootstrap.sh`. Leave the existing
resume-suppression entry in place and **before** the new one (order
matters — ADR §3.3 bullet 1).

**Files touched:**
- `.claude/settings.json` (edit only — append one entry to the
  `SessionStart.hooks[0].hooks` array).

**Implementation anchors:**

| Anchor                                                                                          | ADR location |
|-------------------------------------------------------------------------------------------------|--------------|
| New entry: `{"type":"command","command":"bash scripts/hooks/inbox-watch-bootstrap.sh"}`         | §3.5         | <!-- orianna: ok -- template or prospective path -->
| Do **NOT** add `UserPromptSubmit` entry referencing inbox anything                              | §3.5, §5 item 10 |
| Do **NOT** add `PreToolUse` entry for inbox                                                      | §3.5         |
| JSON remains valid (`jq -e . .claude/settings.json`)                                             | —            | <!-- orianna: ok -- template or prospective path -->

**Acceptance:**
- Diff shows **only** the new hook entry added (no reformatting, no
  reordering of unrelated keys — Karpathy "surgical changes").
- `jq -e '.hooks.SessionStart[0].hooks | length' .claude/settings.json` <!-- orianna: ok -- template or prospective path -->
  returns `2` (was `1`).
- `jq -e '.hooks.SessionStart[0].hooks[1].command' .claude/settings.json` <!-- orianna: ok -- template or prospective path -->
  returns the exact string `"bash scripts/hooks/inbox-watch-bootstrap.sh"`. <!-- orianna: ok -- template or prospective path -->
- `jq -e '.hooks | to_entries[] | select(.key=="UserPromptSubmit")' .claude/settings.json` <!-- orianna: ok -- template or prospective path -->
  returns nothing OR returns an entry with no inbox-related command.

**DoD:** `bash scripts/hooks/test-hooks.sh` (or whatever the existing <!-- orianna: ok -- template or prospective path -->
local hooks test runner is) still passes; `jq -e .` validates the
file.
**Blockers:** none.
**Depends on:** IW.1, IW.2 (the scripts they add must exist on disk
before the hook entry references them, else the first SessionStart
that fires the hook 500s).

---

### IW.5 — Flip xfail harness green (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl; same commit as IW.1 – IW.4, or a
fixup squashed in before push)
**ADR refs:** §5 (acceptance §5 items 1–12), "Test plan" bullets 1–4.

**What:** Remove the xfail-wrapper from every test function in
`scripts/hooks/tests/inbox-watch-test.sh`. Every assertion now runs
directly; harness exits 0 iff the implementation is correct.

**Files touched:**
- `scripts/hooks/tests/inbox-watch-test.sh` (edit).

**Acceptance:**
- `bash scripts/hooks/tests/inbox-watch-test.sh` exits 0 with no <!-- orianna: ok -- template or prospective path -->
  `XFAIL:` lines and no `XPASS:` lines; only `PASS:` output per test
  case.
- Regression greps inside the harness all return the expected-empty
  result:
  - `! grep -rn 'strawberry-inbox' .claude/plugins` (dir absent or <!-- orianna: ok -- template or prospective path -->
    no hits).
  - `! grep -rn 'channelsEnabled\|--channels\|development-channels' scripts .claude`.
  - `! grep -rn 'UserPromptSubmit' .claude/settings.json | grep -i inbox`. <!-- orianna: ok -- template or prospective path -->
  - `! test -f scripts/hooks/inbox-nudge.sh`. <!-- orianna: ok -- template or prospective path -->
  - `! grep -rn 'pending message(s)\. Run /check-inbox to read them\.' scripts/hooks/`. <!-- orianna: ok -- template or prospective path -->
- `shellcheck scripts/hooks/tests/inbox-watch-test.sh` clean. <!-- orianna: ok -- template or prospective path -->

**DoD:**
- CI (whatever local hook invokes test harnesses under
  `scripts/hooks/tests/`) green. Pre-commit unit-test hook (Rule 14) <!-- orianna: ok -- template or prospective path -->
  does not block.
- Pre-push TDD hook (Rule 12) accepts the push because the xfail
  commit (IW.0) precedes this impl commit on the same branch and
  references the plan path.

**Commit message (for the squashed impl commit):**
```
chore: strawberry inbox watcher — Monitor-driven real-time inbox

Implements the v3.1 plan:
  - scripts/hooks/inbox-watch.sh (Phase 0 cleanup + Phase 1 sweep +
    Phase 2 live watch; fswatch → inotifywait → 3 s poll fallback).
  - scripts/hooks/inbox-watch-bootstrap.sh (SessionStart nudge).
  - .claude/skills/check-inbox/SKILL.md (recovered from fb1bd4f and
    extended with archive-to-inbox/archive/YYYY-MM/ semantics +
    read_at frontmatter).
  - .claude/settings.json — one new SessionStart.hooks entry.
  - Flips scripts/hooks/tests/inbox-watch-test.sh to fully green.

Implements plans/in-progress/2026-04-20-strawberry-inbox-channel.md.
```

**Blockers:** none.
**Depends on:** IW.1, IW.2, IW.3, IW.4.

---

### Execution order (tl;dr for Evelynn)

```
IW.0 (Rakan, commit 1 on inbox-watch-v3)
  └── IW.1 (Viktor) ─┐
  └── IW.2 (Viktor) ─┤
  └── IW.3 (Viktor) ─┴─ IW.4 (Viktor) ── IW.5 (Viktor, flip green) ── PR open
```

Single branch. Two commit slots. One PR. Two reviewers (Senna + Lucian).

### Acceptance-gate cross-reference

| Task | Satisfies ADR §5 items | Satisfies ADR "Test plan" bullets |
|------|------------------------|------------------------------------|
| IW.0 | — (scaffolds the checks for everything below) | Unit-level, retention, archive-flow, regression (all as xfails) |
| IW.1 | 1, 6, 7, 8, 11, 12     | Unit-level, archive-retention       |
| IW.2 | 5, 6, 8                | Unit-level                          |
| IW.3 | 3, 4, 11               | archive-flow                        |
| IW.4 | 5, 9, 10               | Regression floor                    |
| IW.5 | (flip) 1, 3, 5, 6, 7, 8, 10, 11, 12 | All four harness sections  |

Acceptance §5 items **2** (live mid-session delivery) and **9**
(no Channels/MCP/dev-flag regressions — partially covered by IW.5's
greps, but the no-Channels live test needs a real session) are
manual-only; they land in the E2E report archived under
`assessments/qa-reports/2026-04-…-inbox-watch.md` referenced from the <!-- orianna: ok -- template or prospective path -->
PR body. Evelynn + Sona each run one E2E turn; report links both.

### Rollback

- **Pre-merge:** close PR, delete branch; no system state changes.
- **Post-merge, pre-prod-usage:** revert the merge commit; no database
  state to roll back.
- **Post-merge, post-first-boot:**
  - Delete `scripts/hooks/inbox-watch.sh`,
    `scripts/hooks/inbox-watch-bootstrap.sh`, `.claude/skills/check-inbox/` <!-- orianna: ok -- template or prospective path -->
    (or `touch .no-inbox-watch` for an instant local disable).
  - Remove the new `SessionStart.hooks` entry from `.claude/settings.json`. <!-- orianna: ok -- template or prospective path -->
  - No data loss: messages remain in `agents/<coord>/inbox/**` as <!-- orianna: ok -- template or prospective path -->
    `status: pending`; archived messages remain under
    `inbox/archive/YYYY-MM/`. Both are static markdown files. <!-- orianna: ok -- template or prospective path -->
  - The 7-day archive TTL is only enforced when the watcher boots, so
    rolling back the watcher **freezes** archive retention — same
    state as `.no-inbox-watch` opt-out. Acceptable.

### Open questions for Aphelios (OQ-K#)

- **OQ-K1 — fswatch install cadence.** The ADR assumes `fswatch` is
  already installed on Duong's Mac (Homebrew). It's not validated in
  this plan; the poll fallback (3 s) is the fallback if absent. If
  Evelynn wants sub-second live delivery as a floor (not an
  aspiration), a separate plan should add an Orianna-gated install
  step. Not blocking for this breakdown; Viktor ships all three code
  paths.
- **OQ-K2 — line-format em-dash robustness.** The contract uses
  `—` (U+2014). If anyone copy-pastes the pattern through a tool
  that normalizes to a hyphen, the watcher filter regex fails open
  (no emission) rather than fails closed. Acceptable for v3, but
  worth a sentinel test in the harness — **covered** by IW.0's
  `test_line_format_contract` byte-level regex.

### Sign-off

This breakdown was prepared by Aphelios on 2026-04-21 against
Azir's v3.1 plan with Orianna signature
`sha256:d5979ae9013e1af1748366f0f0b837047082730681eb35a9640b7abcbee90e4a:2026-04-21T03:59:37Z`.

No ADR changes were made in the process of producing this
breakdown. All `<!-- orianna: ok -- prospective path or non-file token -->` markers on prospective paths
from the ADR are propagated above onto the matching task entries.

## Test plan detail (Xayah)

Companion to this ADR. Xayah authors this plan and hands off
implementation to Rakan (complex-track test-implementer). No tests are
self-implemented here; every section below is a spec, an xfail
skeleton, or a pointer to a file Rakan will create.

### TD.0 Scope and hand-off

- **Surfaces under test** (from the ADR §3): `inbox-watch.sh`, <!-- orianna: ok -- template or prospective path -->
  `inbox-watch-bootstrap.sh`, `/check-inbox` skill, Phase 0 cleanup, <!-- orianna: ok -- template or prospective path -->
  opt-out, dual-coordinator parity, Monitor event-stream semantics.
- **Test author (implementer)**: Rakan.
- **Test executor**: Vi may run the batteries in CI.
- **Audit owner**: Xayah (this section is the coverage contract).

Every prospective test path below carries a `<!-- orianna: ok -- prospective path or non-file token -->` marker
so the fact-check gate recognises them as approved future deliverables
against this plan.

### TD.1 Invariants the tests must protect

Ordered by blast radius. A regression in any of these is a release-
blocking bug for the inbox channel.

| # | Invariant | Primary source |
|---|---|---|
| I1 | Top-level `agents/<coord>/inbox/` contains **only** `status: pending` files after `/check-inbox` runs to completion. | ADR §3.4, §4.1 | <!-- orianna: ok -- template or prospective path -->
| I2 | `inbox-watch.sh` emits exactly one `INBOX:` stdout line per `status: pending` file during the Phase 1 sweep, and zero lines per `status: read` file. | ADR §3.2, §5 item 1 | <!-- orianna: ok -- template or prospective path -->
| I3 | Line contract: `^INBOX: [^ ]+\.md — from [^ ]+ — [a-z]+$` (em-dash, three fields). | ADR §3.2 line-format block |
| I4 | `.no-inbox-watch` at repo root causes both the bootstrap script and `inbox-watch.sh` to exit 0 silently **before** Phase 0 (cleanup is suppressed too — total opt-out). | ADR §3.2 opt-out, §4.4 | <!-- orianna: ok -- template or prospective path -->
| I5 | Phase 0 deletes `archive/**/*.md` whose mtime is > 7 days old and prunes empty month-bucket dirs; it never touches files in the pending set (`inbox/*.md`). | ADR §3.2 Phase 0, §4.4, §5 item 12 | <!-- orianna: ok -- template or prospective path -->
| I6 | Phase 1 glob is flat (`inbox/*.md`) — `archive/**` subdirs are never swept as pending. | ADR §3.2 Phase 1, §6 "Archive dir accidentally watched" | <!-- orianna: ok -- template or prospective path -->
| I7 | During `/check-inbox`'s frontmatter rewrite + `mv`, the watcher does not re-emit `INBOX:` for the same filename (filter discipline). | ADR §3.2 filter-discipline paragraph, §5 item 11, §6 |
| I8 | Identity-resolution chain order is stable: `CLAUDE_AGENT_NAME` → `STRAWBERRY_AGENT` → `.claude/settings.json .agent` → silent exit 0. | ADR §3.2 identity block | <!-- orianna: ok -- template or prospective path -->
| I9 | `/agent-ops send` writes to `inbox/` (flat), never `archive/`. | ADR §4.1, §5 item 4 | <!-- orianna: ok -- template or prospective path -->
| I10 | Resume / clear / compact SessionStart sources do **not** emit the bootstrap nudge. | ADR §3.3 point 1, §5 item 5 |
| I11 | Archive-path computation uses `timestamp:` frontmatter; falls back to file mtime if absent. | ADR §3.4 step 3 |
| I12 | `/check-inbox` is idempotent under concurrent invocation (second `mv` is a no-op, not an error that aborts the batch). | ADR §3.4 concurrency paragraph |
| I13 | Monitor stdout contract contains no debug/echo lines outside the `INBOX:` format (auto-kill hygiene). | ADR §4.3, §6 "Noisy-monitor auto-kill" |

### TD.2 Test-layer topology

Four batteries, each with a dedicated xfail skeleton committed ahead of
the implementation commit (Rule 12 TDD gate). The tests live in a single
harness under `scripts/hooks/tests/` to plug into the existing pre-commit <!-- orianna: ok -- template or prospective path -->
test runner with no new CI job.

| Layer | File | Purpose |
|---|---|---|
| Unit — watcher | `scripts/hooks/tests/inbox-watch.test.sh` <!-- orianna: ok -- prospective path or non-file token --> | Direct `bash inbox-watch.sh` invocations with `INBOX_WATCH_ONESHOT=1`; fixture inbox dirs. |
| Unit — bootstrap | `scripts/hooks/tests/inbox-watch-bootstrap.test.sh` <!-- orianna: ok -- prospective path or non-file token --> | Direct `bash inbox-watch-bootstrap.sh` invocations with stubbed stdin JSON. |
| Integration | `scripts/hooks/tests/inbox-channel.integration.test.sh` <!-- orianna: ok -- prospective path or non-file token --> | Watcher + check-inbox + cleanup together against a scratch repo layout. |
| Fault-injection | `scripts/hooks/tests/inbox-channel.fault.test.sh` <!-- orianna: ok -- prospective path or non-file token --> | Race conditions, watcher kill/restart, corrupt frontmatter, filesystem edge cases. |

Optional fifth (manual, not in CI):

| Layer | Artifact | Purpose |
|---|---|---|
| End-to-end empirical | `assessments/qa-reports/YYYY-MM-DD-inbox-watch.md` | Live Evelynn and Sona dual-coordinator walkthrough; captures wall-clock latency + event text. Gates promotion `in-progress → implemented`. | <!-- orianna: ok -- template or prospective path -->

### TD.3 Test fixtures

Every test case constructs its own scratch tree under `$TMPDIR/inbox-
test-<pid>/` and exports `STRAWBERRY_AGENT=evelynn` (or `sona`) plus a
`REPO_ROOT_OVERRIDE` that the scripts under test must respect. Rakan's
implementation of `inbox-watch.sh` must accept either a `REPO_ROOT` <!-- orianna: ok -- template or prospective path -->
env var or `pwd`-based resolution; the test plan calls for `pwd`-based
resolution with `cd $SCRATCH` in the setup.

Standard fixture generators (helper functions Rakan will implement at
the top of the harness):

- `make_pending <dir> <name> [--from=S] [--prio=P] [--timestamp=T]` —
  writes a canonical pending message.
- `make_read <dir> <name> [--read-at=T]` — writes a read message
  (used only for "never emit" tests).
- `make_archived <dir> <yyyy-mm> <name> [--mtime-days-ago=N]` — writes
  a file under `archive/<yyyy-mm>/` and backdates mtime via `touch <!-- orianna: ok -- template or prospective path -->
  -t`. Use `touch -t` on BSD (macOS) and `touch -d` on GNU (Linux) —
  the helper detects which is available.
- `corrupt_frontmatter <path>` — truncates the closing `---`, used for
  corrupt-frontmatter cases.

### TD.4 Unit battery — `inbox-watch.test.sh` (I1, I2, I3, I4, I5, I6, I8, I11, I13) <!-- orianna: ok -- template or prospective path -->

XFAIL marker: `# XFAIL: scripts/hooks/inbox-watch.sh not yet implemented`. <!-- orianna: ok -- template or prospective path -->
Harness pattern identical to `scripts/hooks/tests/pre-compact-gate.test.sh`
(committed reference) — test file exits 0 and reports all cases as XFAIL
when the target script is missing.

#### Phase 1 emission cases

| Case | Fixture | Assertion |
|---|---|---|
| U-W-01 | Empty `inbox/` dir | stdout empty; exit 0; stderr empty. | <!-- orianna: ok -- template or prospective path -->
| U-W-02 | Single `status: pending` file | Exactly one stdout line; line matches regex `^INBOX: <name>\.md — from <sender> — <priority>$`; exit 0. |
| U-W-03 | N=10 pending files, varied senders + priorities | N lines, one per file; each matches line-format regex; no duplicates; order unspecified but deterministic within a run (document whatever order the impl picks, assert on the set via `sort`). |
| U-W-04 | Mix of pending + read files (flat) | Only the pending files produce `INBOX:` lines; the read files produce zero lines. |
| U-W-05 | `archive/2026-04/foo.md` with `status: pending` (edge case — archive should never hold pending, but defend in depth) | Phase 1 does not emit a line for the archive entry; exit 0. Enforces I6. | <!-- orianna: ok -- template or prospective path -->
| U-W-06 | File without `status:` frontmatter key | Zero emission for that file; exit 0. |
| U-W-07 | File with `status: read` but **no** `read_at` | Zero emission; exit 0. |
| U-W-08 | File with `status:  pending ` (whitespace-padded) | One emission. Frontmatter parsing must be tolerant of surrounding whitespace. |
| U-W-09 | File that matches `*.md` but is **actually a directory** (edge) | Skipped silently; exit 0. |

#### Phase 0 cleanup cases (I5)

| Case | Fixture | Assertion |
|---|---|---|
| U-C-01 | `archive/2026-03/old.md` mtime 10 days ago + `archive/2026-04/fresh.md` mtime 1 hour ago | After run: `old.md` gone, `fresh.md` present, `archive/2026-03/` pruned (empty), `archive/2026-04/` retained. | <!-- orianna: ok -- template or prospective path -->
| U-C-02 | `archive/2026-03/a.md` (10 days) + `archive/2026-03/b.md` (1 hour) | After run: `a.md` gone, `b.md` present, `archive/2026-03/` retained (non-empty). | <!-- orianna: ok -- template or prospective path -->
| U-C-03 | No `archive/` dir at all | Phase 0 no-ops silently; stderr does **not** contain "No such file or directory". Exit 0. | <!-- orianna: ok -- template or prospective path -->
| U-C-04 | `archive/` dir empty | Phase 0 no-ops; no files deleted; `archive/` retained. | <!-- orianna: ok -- template or prospective path -->
| U-C-05 | `archive/2026-03/old.md` mtime exactly 7 days (boundary) | File **not** deleted (POSIX `-mtime +7` is strictly *greater than* 7×24h). | <!-- orianna: ok -- template or prospective path -->
| U-C-06 | Non-`.md` file under `archive/` (e.g., `archive/.DS_Store`) | Untouched by Phase 0 (the `-name '*.md'` filter). | <!-- orianna: ok -- template or prospective path -->
| U-C-07 | Phase 0 runs, then Phase 1 still executes | `INBOX_WATCH_ONESHOT=1` combined fixture: backdated archive file + one pending file. Assert both (a) backdated file gone and (b) `INBOX:` line emitted. |

#### Opt-out cases (I4)

| Case | Fixture | Assertion |
|---|---|---|
| U-O-01 | `touch .no-inbox-watch`; pending file exists in inbox | Exit 0; stdout empty; **archive cleanup does not run** (verify with a backdated archive file still present after the run). |
| U-O-02 | `.no-inbox-watch` exists; no inbox dir at all | Exit 0 silently. |

#### Identity resolution cases (I8)

| Case | Env / config | Expected resolved identity |
|---|---|---|
| U-I-01 | `CLAUDE_AGENT_NAME=evelynn` + `STRAWBERRY_AGENT=sona` + settings.agent=caitlyn | evelynn (first wins) |
| U-I-02 | `STRAWBERRY_AGENT=sona` + settings.agent=caitlyn, `CLAUDE_AGENT_NAME` unset | sona |
| U-I-03 | only settings.agent=Evelynn (mixed case) | evelynn (case-insensitive match per ADR §3.2) |
| U-I-04 | none of the three sources | Exit 0, stdout empty. |
| U-I-05 | `CLAUDE_AGENT_NAME=nonexistent` + no `agents/nonexistent/` dir | Exit 0, stdout empty. | <!-- orianna: ok -- template or prospective path -->

#### Line-format contract (I3, I13)

| Case | Fixture | Assertion |
|---|---|---|
| U-F-01 | Pending file with `priority: high` | Line exactly matches `^INBOX: <name>\.md — from <sender> — high$`; no trailing whitespace. |
| U-F-02 | Pending file with unusual but valid `priority: urgent-review` | Regex `^INBOX: [^ ]+\.md — from [^ ]+ — [a-z\-]+$` still matches. |
| U-F-03 | Pending file with filename containing spaces | Either the filename is single-token in the emitted line or the line still parses by a quoted variant. Impl choice; test asserts whichever is specified. Open question O1. |
| U-F-04 | Stdout hygiene: no lines outside the `INBOX:` prefix when running against a pure fixture with no errors | `grep -v '^INBOX: ' stdout | wc -l` equals 0. Guards I13. |

#### Phase 2 (live-watch) smoke — optional, time-bounded

Phase 2 is hard to unit-test without `fswatch`/`inotifywait`. Rakan's
harness should include one optional case that starts `inbox-watch.sh` in <!-- orianna: ok -- template or prospective path -->
the background (no `ONESHOT`) with a 5 s timeout, drops a new pending
file after 0.5 s, kills the watcher at 4 s, and asserts stdout contains
one `INBOX:` line for the dropped file. Skip (XFAIL) if neither
`fswatch` nor `inotifywait` is on `PATH`.

### TD.5 Unit battery — `inbox-watch-bootstrap.test.sh` (I4, I8, I10) <!-- orianna: ok -- template or prospective path -->

XFAIL marker: `# XFAIL: scripts/hooks/inbox-watch-bootstrap.sh not yet implemented`. <!-- orianna: ok -- template or prospective path -->

| Case | stdin payload | Expected |
|---|---|---|
| U-B-01 | `{"hook_event_name":"SessionStart","source":"startup"}` with `CLAUDE_AGENT_NAME=evelynn` | Exit 0; stdout is valid JSON with `hookSpecificOutput.hookEventName == "SessionStart"` and `additionalContext` containing the literal strings `Monitor`, `bash scripts/hooks/inbox-watch.sh`, and `/check-inbox`. | <!-- orianna: ok -- template or prospective path -->
| U-B-02 | `source: resume` | Exit 0; stdout empty (I10). |
| U-B-03 | `source: clear` | Exit 0; stdout empty (I10). |
| U-B-04 | `source: compact` | Exit 0; stdout empty (I10). |
| U-B-05 | `source: startup` + no identity resolvable | Exit 0; stdout empty. |
| U-B-06 | `source: startup` + `.no-inbox-watch` present | Exit 0; stdout empty (I4). |
| U-B-07 | Malformed JSON on stdin (`"not json"`) | Exit 0; stdout empty; no uncaught shell trace on stderr. |
| U-B-08 | Missing `source` field | Treat as not-startup; exit 0; stdout empty. |
| U-B-09 | `source: startup` + `CLAUDE_AGENT_NAME=sona` (dual-coordinator parity) | Same shape as U-B-01 but `additionalContext` references `sona`'s inbox. |

### TD.6 Integration battery — `inbox-channel.integration.test.sh` (I1, I7, I9, I11, I12) <!-- orianna: ok -- template or prospective path -->

Driver: a scratch repo layout with both `agents/evelynn/` and <!-- orianna: ok -- template or prospective path -->
`agents/sona/`. Integration means running the real scripts end-to-end. <!-- orianna: ok -- template or prospective path -->

#### Watcher-then-check-inbox flow (I1, I7, I11)

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-01 | Two pending files in `agents/evelynn/inbox/`, each with a `timestamp: 2026-04-21 14:23` frontmatter | (a) Run `inbox-watch.sh` with `ONESHOT=1`; capture stdout. (b) Run the `/check-inbox` skill's disposition logic. | After (a): two `INBOX:` lines. After (b): `inbox/` has zero `*.md` files; both originals now live at `archive/2026-04/<original-name>` with `status: read` and a valid ISO-8601 `read_at`. | <!-- orianna: ok -- template or prospective path -->
| IT-02 | Pending file with **no** `timestamp:` frontmatter | Run `/check-inbox` disposition. | File moves to `archive/<mtime-YYYY-MM>/<name>` (I11 fallback). | <!-- orianna: ok -- template or prospective path -->
| IT-03 | Pending file with `timestamp: malformed-not-a-date` | Run `/check-inbox` disposition. | Either archive path falls through to mtime (documented fallback), or skill refuses with a clean error and leaves the file in place. Open question O2. |
| IT-04 | Filter discipline: run watcher in background (Phase 2), then run check-inbox, then kill watcher | Count `INBOX:` lines in stdout | Exactly one line per original pending file — the check-inbox frontmatter rewrite must **not** produce a second event (I7). |

#### Sender-side invariant (I9)

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-05 | Scratch repo | Invoke `/agent-ops send evelynn "ping"` (or its Bash equivalent) | The new file appears at `agents/evelynn/inbox/<name>.md` flat; **no** file is ever created under `archive/`; the frontmatter has `status: pending`. | <!-- orianna: ok -- template or prospective path -->
| IT-06 | Static grep in the `/agent-ops` skill body | grep for `archive` in the `send` subcommand block | Zero matches. |

#### Concurrency (I12)

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-07 | One pending file | Invoke `/check-inbox` disposition twice in parallel (shell `&`, then `wait`) | Exactly one archive file; the "loser" invocation exits 0; end-state invariants hold. |
| IT-08 | Ten pending files | Five parallel `/check-inbox` runs | All ten files end up archived; no duplicates; no originals left behind. |

#### Dual-coordinator parity

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-09 | Fixture repo with both `agents/evelynn/inbox/*.md` and `agents/sona/inbox/*.md` populated; `CLAUDE_AGENT_NAME=evelynn` | Run `inbox-watch.sh` ONESHOT | Only evelynn's pending files emit `INBOX:` lines. | <!-- orianna: ok -- template or prospective path -->
| IT-10 | Same fixture; flip `CLAUDE_AGENT_NAME=sona` | Run `inbox-watch.sh` ONESHOT | Only sona's pending files emit. | <!-- orianna: ok -- template or prospective path -->
| IT-11 | Two separate scratch processes, one per coordinator, each running its own watcher concurrently | Drop a pending file into each inbox | Each process's stdout contains exactly the line for its own inbox. |
| IT-12 | `inbox-watch-bootstrap.sh` stdin with `CLAUDE_AGENT_NAME=sona`; same with `evelynn` | Compare `additionalContext` outputs | Structurally identical; differ only in the agent name and path string. | <!-- orianna: ok -- template or prospective path -->

### TD.7 Fault-injection battery — `inbox-channel.fault.test.sh` (I5, I6, I7, I12, I13) <!-- orianna: ok -- template or prospective path -->

#### Corrupt frontmatter

| Case | Setup | Assertion |
|---|---|---|
| FI-01 | `inbox/foo.md` with only `---\nfrom: sona\n` (no closing `---`, no status) | `inbox-watch.sh` ONESHOT: zero emission; exit 0; stderr does not contain uncaught shell errors. | <!-- orianna: ok -- template or prospective path -->
| FI-02 | `inbox/foo.md` with binary garbage in the first 4 KB | Zero emission; exit 0; stderr may carry a one-line skip notice but must not abort the run. | <!-- orianna: ok -- template or prospective path -->
| FI-03 | `inbox/foo.md` is a zero-byte file | Zero emission; exit 0. | <!-- orianna: ok -- template or prospective path -->
| FI-04 | `inbox/foo.md` is a symlink pointing to a file outside the repo | Either follow the link and parse (document and assert), or skip. Open question O3. | <!-- orianna: ok -- template or prospective path -->
| FI-05 | Frontmatter with `status: pending` duplicated twice | Impl picks deterministic rule (first-wins or last-wins); test asserts whichever is specified. |

#### Filesystem races

| Case | Setup | Assertion |
|---|---|---|
| FI-06 | `inbox/foo.md` exists at Phase 1 listing time but is deleted before frontmatter-read | Zero emission; exit 0; no `cat: No such file` leak to stderr. | <!-- orianna: ok -- template or prospective path -->
| FI-07 | New file atomically moved into `inbox/` via `mv $TMP/new.md inbox/` during Phase 1 | Either emitted in Phase 1 or picked up by Phase 2. Never both. | <!-- orianna: ok -- template or prospective path -->
| FI-08 | `inbox/` is deleted outright while watcher is in Phase 2 | Watcher exits nonzero with a logged stderr line. Monitor surfaces the failure per ADR §3.2 "Lifecycle". | <!-- orianna: ok -- template or prospective path -->
| FI-09 | Filesystem full during `/check-inbox` frontmatter rewrite | Rewrite fails; skill aborts; **original file is not deleted or moved**. |

#### Concurrent watcher + check-inbox (I7 hardening)

| Case | Setup | Assertion |
|---|---|---|
| FI-10 | Start watcher in Phase 2; then concurrently: (a) drop a new pending file, (b) immediately run `/check-inbox` | Exactly one `INBOX:` event for the file. Repeat 20 times to shake out races. |
| FI-11 | Start watcher; run `/check-inbox` on a pre-existing pending file; observe ordering | Timeline is: emit → rewrite (pending→read) → mv. Total `INBOX:` lines = 1. |

#### Monitor stream loss / reconnect

| Case | Setup | Assertion |
|---|---|---|
| FI-12 | Start watcher in Phase 2 piping stdout into `head -n 2` (closes the pipe after 2 lines) | After pipe closes, watcher receives `SIGPIPE` and exits. Exit code 0 or 141 (SIGPIPE). No tight retry loop. |
| FI-13 | Kill watcher PID with SIGTERM mid-Phase-2 | Clean exit; no stray child processes (`pgrep -P <watcher-pid>` confirms no orphans). |
| FI-14 | Restart the watcher after a kill: run ONESHOT, then start Phase 2, then another pending file drops | Restarted run emits exactly one line per current pending file on its sweep, then picks up new drops in Phase 2. |

#### Archive-cleanup fault cases (I5 hardening)

| Case | Setup | Assertion |
|---|---|---|
| FI-15 | `archive/2026-03/` owned by a different user (`chmod 000`) | Phase 0 logs no stderr (the `2>/dev/null` redirect absorbs permission errors), continues to Phase 1 without aborting. | <!-- orianna: ok -- template or prospective path -->
| FI-16 | Clock skew: file mtime set **in the future** | `find -mtime +7` does not match future-dated files → file survives. |
| FI-17 | Huge archive (1000 files under `archive/2026-03/`, half stale) | Phase 0 completes in < 2 seconds on a stock macOS laptop; all 500 stale files deleted; all 500 fresh files retained. | <!-- orianna: ok -- template or prospective path -->

### TD.8 Migration assertions (first-boot parity)

**D2 ruling — prune, not migrate:** Duong ruled on O5 that existing
`status: read` files in `inbox/` are **pruned before watcher boot**, <!-- orianna: ok -- template or prospective path -->
not migrated. There is no `scripts/hooks/inbox-migrate.sh`. Before the <!-- orianna: ok -- template or prospective path -->
watcher ships, any pre-existing `status: read` files in the live
coordinator inbox must be manually pruned (or deleted) so the first
Phase 1 sweep operates on a pending-only inbox. This replaces the
migration-script approach described in the original test plan draft.

The relevant integration tests (formerly MIG-01 through MIG-07) are
replaced by:

| Case | Setup | Run | Assertion |
|---|---|---|---|
| MIG-P-01 | Fixture mirroring legacy state: N pending + M read files flat in `inbox/`, no `archive/` | **Manually prune** all `status: read` files; then run `inbox-watch.sh` ONESHOT | After prune: `inbox/` contains exactly N `*.md` files (all `status: pending`); watcher emits exactly N `INBOX:` lines; zero lines reference the pruned files. Exit 0. | <!-- orianna: ok -- template or prospective path -->
| MIG-P-02 | Post-prune state from MIG-P-01 | Run watcher a second time (`INBOX_WATCH_ONESHOT=1`) | Exactly N `INBOX:` lines again (idempotent sweep against the pending set). No archive entries swept. |

The implementation commit must **not** ship `scripts/hooks/inbox-migrate.sh` <!-- orianna: ok -- template or prospective path -->
or any reference to it. The QA report for this plan must document the
pre-watcher manual prune step.

### TD.9 Regression-floor battery

Mirrors ADR §5 items 9, 10 and the "Test plan" block at the ADR's bottom.
These run at the top of every harness file.

| Check | Command (conceptual) | Expected |
|---|---|---|
| R-01 | `grep -r 'strawberry-inbox' .claude/plugins` | no matches (dir absent) | <!-- orianna: ok -- template or prospective path -->
| R-02 | `grep -rE 'channelsEnabled|--channels|development-channels' scripts/ .claude/` | no matches | <!-- orianna: ok -- template or prospective path -->
| R-03 | `find . -name '.mcp.json' -path '*/strawberry-inbox/*'` | no matches | <!-- orianna: ok -- template or prospective path -->
| R-04 | `grep -rn 'UserPromptSubmit' .claude/settings.json` | no entry naming inbox-nudge / inbox-watch | <!-- orianna: ok -- template or prospective path -->
| R-05 | `test ! -f scripts/hooks/inbox-nudge.sh` | file absent | <!-- orianna: ok -- template or prospective path -->
| R-06 | `grep -rn 'pending message(s)\. Run /check-inbox to read them\.' scripts/hooks/` | no matches (v2 phrasing fingerprint) | <!-- orianna: ok -- template or prospective path -->
| R-07 | `grep -rn 'agents/.*/inbox/archive' .claude/skills/agent-ops/` | no matches (I9 code-level regression) | <!-- orianna: ok -- template or prospective path -->
| R-08 | Sender-side: `/agent-ops send` step list in `SKILL.md` does not reference `archive/` | document match absence | <!-- orianna: ok -- template or prospective path -->

### TD.10 Open questions

- **O1** — Filename with spaces: should `/agent-ops send` reject, slug-
  ify, or pass through? Recommend slugify. Impacts U-F-03.
- **O2** — Malformed `timestamp:` frontmatter on archive: fall through to
  mtime-based month, or refuse? Recommend fall-through. Impacts IT-03.
- **O3** — Symlink handling in `inbox/*.md`: follow or skip? Recommend <!-- orianna: ok -- template or prospective path -->
  skip. Impacts FI-04.
- **O4** — (Closed by D2 ruling.) No migration script; existing `status:
  read` files are pruned manually before watcher boot.
- **O5** — (Closed by D2 ruling.) No `scripts/hooks/inbox-migrate.sh` <!-- orianna: ok -- template or prospective path -->
  will be shipped. Prune instead. See TD.8.
- **O6** — Performance envelope for FI-17 (1000 archive files): < 2s is
  a guess. If the CI runner is slower, relax to < 10s. Rakan to tune.

### TD.11 CI and TDD posture

- No new CI jobs — all four test files plug into the existing
  pre-commit hook test harness (`scripts/hooks/tests/`). <!-- orianna: ok -- template or prospective path -->
- Each test file is committed **before** its target script per Rule 12,
  with the `XFAIL:` marker at the top.
- On the implementation commit that lands the scripts, the xfail marker
  is removed in the same commit; tests must then pass green.
- The fault-injection battery is **required** for merge; it is not an
  optional lint.

### TD.12 Handoff

- **To Rakan**: implement the four `.test.sh` files above as xfail <!-- orianna: ok -- template or prospective path -->
  skeletons, one commit per file, each referencing its case range.
  Then implement the scripts + skill per the ADR and flip the tests
  green.
- **Audit cadence**: Xayah re-reviews Rakan's PR before merge,
  specifically checking (a) the fault-injection cases are not stubbed
  out, (b) the prune pre-condition (TD.8) is documented in the QA
  report, (c) I7 has its 20-iteration race harness.

<!-- orianna: ok -- prospective path or non-file token --> prospective paths recap (Xayah test plan):
- `scripts/hooks/tests/inbox-watch.test.sh` <!-- orianna: ok -- template or prospective path -->
- `scripts/hooks/tests/inbox-watch-bootstrap.test.sh` <!-- orianna: ok -- template or prospective path -->
- `scripts/hooks/tests/inbox-channel.integration.test.sh` <!-- orianna: ok -- template or prospective path -->
- `scripts/hooks/tests/inbox-channel.fault.test.sh` <!-- orianna: ok -- template or prospective path -->
- `assessments/qa-reports/YYYY-MM-DD-inbox-watch.md` (manual E2E, gate <!-- orianna: ok -- template or prospective path -->
  for `in-progress → implemented`)

## Architecture impact

No architecture/ files modified. The inbox watcher ships as Monitor-driven scripts under scripts/hooks/ and a skill update; the inbox directory layout (agents/coordinator/inbox/) is pre-existing convention. No new architectural patterns in architecture/.

## Test results

- PR #18 merged: https://github.com/harukainguyen1411/strawberry-agents/pull/18
- All required checks green at merge.
