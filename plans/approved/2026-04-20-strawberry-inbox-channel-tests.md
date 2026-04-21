---
title: Strawberry inbox watcher — test plan (xayah)
status: approved
concern: personal
owner: xayah
author: xayah
created: 2026-04-21
date: 2026-04-21
orianna_gate_version: 2
tests_required: false
parent: plans/approved/2026-04-20-strawberry-inbox-channel.md
tags: [inbox, coordinator, hooks, monitor, tests]
---

<!--
  tests_required: false — this document *is* the test plan for the parent
  ADR (`2026-04-20-strawberry-inbox-channel.md`). Requiring a test plan
  for a test plan is circular. The parent ADR carries `tests_required:
  true`; that obligation is discharged by the batteries specified below.
-->

## Test plan

This document is itself the test plan for the parent ADR. The test
batteries, fixtures, invariants, and fault-injection specs live in
§2–§9 below. Implementation hand-off is §12.

# Strawberry inbox watcher — test plan

Companion to `plans/approved/2026-04-20-strawberry-inbox-channel.md`
(hereafter "the ADR"). Xayah authors this plan and hands off implementation
to Rakan (complex-track test-implementer). No tests are self-implemented
here; every section below is a spec, an xfail skeleton, or a pointer to a
file Rakan will create.

## 0. Scope and hand-off

- **Surfaces under test** (from the ADR §3): `inbox-watch.sh`,
  `inbox-watch-bootstrap.sh`, `/check-inbox` skill, Phase 0 cleanup,
  opt-out, dual-coordinator parity, Monitor event-stream semantics.
- **Test author (implementer)**: Rakan.
- **Test executor**: Vi may run the batteries in CI.
- **Audit owner**: Xayah (this file is the coverage contract).

Every prospective test path below carries a `<!-- orianna: ok -->` marker
so the fact-check gate recognises them as approved future deliverables
against this plan.

## 1. Invariants the tests must protect

Ordered by blast radius. A regression in any of these is a release-
blocking bug for the inbox channel.

| # | Invariant | Primary source |
|---|---|---|
| I1 | Top-level `agents/<coord>/inbox/` contains **only** `status: pending` files after `/check-inbox` runs to completion. | ADR §3.4, §4.1 |
| I2 | `inbox-watch.sh` emits exactly one `INBOX:` stdout line per `status: pending` file during the Phase 1 sweep, and zero lines per `status: read` file. | ADR §3.2, §5 item 1 |
| I3 | Line contract: `^INBOX: [^ ]+\.md — from [^ ]+ — [a-z]+$` (em-dash, three fields). | ADR §3.2 line-format block |
| I4 | `.no-inbox-watch` at repo root causes both the bootstrap script and `inbox-watch.sh` to exit 0 silently **before** Phase 0 (cleanup is suppressed too — total opt-out). | ADR §3.2 opt-out, §4.4 |
| I5 | Phase 0 deletes `archive/**/*.md` whose mtime is > 7 days old and prunes empty month-bucket dirs; it never touches files in the pending set (`inbox/*.md`). | ADR §3.2 Phase 0, §4.4, §5 item 12 |
| I6 | Phase 1 glob is flat (`inbox/*.md`) — `archive/**` subdirs are never swept as pending. | ADR §3.2 Phase 1, §6 "Archive dir accidentally watched" |
| I7 | During `/check-inbox`'s frontmatter rewrite + `mv`, the watcher does not re-emit `INBOX:` for the same filename (filter discipline). | ADR §3.2 filter-discipline paragraph, §5 item 11, §6 |
| I8 | Identity-resolution chain order is stable: `CLAUDE_AGENT_NAME` → `STRAWBERRY_AGENT` → `.claude/settings.json .agent` → silent exit 0. | ADR §3.2 identity block |
| I9 | `/agent-ops send` writes to `inbox/` (flat), never `archive/`. | ADR §4.1, §5 item 4 |
| I10 | Resume / clear / compact SessionStart sources do **not** emit the bootstrap nudge. | ADR §3.3 point 1, §5 item 5 |
| I11 | Archive-path computation uses `timestamp:` frontmatter; falls back to file mtime if absent. | ADR §3.4 step 3 |
| I12 | `/check-inbox` is idempotent under concurrent invocation (second `mv` is a no-op, not an error that aborts the batch). | ADR §3.4 concurrency paragraph |
| I13 | Monitor stdout contract contains no debug/echo lines outside the `INBOX:` format (auto-kill hygiene). | ADR §4.3, §6 "Noisy-monitor auto-kill" |

## 2. Test-layer topology

Four batteries, each with a dedicated xfail skeleton committed ahead of
the implementation commit (Rule 12 TDD gate). The tests live in a single
harness under `scripts/hooks/tests/` to plug into the existing pre-commit
test runner with no new CI job.

| Layer | File | Purpose |
|---|---|---|
| Unit — watcher | `scripts/hooks/tests/inbox-watch.test.sh` <!-- orianna: ok --> | Direct `bash inbox-watch.sh` invocations with `INBOX_WATCH_ONESHOT=1`; fixture inbox dirs. |
| Unit — bootstrap | `scripts/hooks/tests/inbox-watch-bootstrap.test.sh` <!-- orianna: ok --> | Direct `bash inbox-watch-bootstrap.sh` invocations with stubbed stdin JSON. |
| Integration | `scripts/hooks/tests/inbox-channel.integration.test.sh` <!-- orianna: ok --> | Watcher + check-inbox + cleanup together against a scratch repo layout. |
| Fault-injection | `scripts/hooks/tests/inbox-channel.fault.test.sh` <!-- orianna: ok --> | Race conditions, watcher kill/restart, corrupt frontmatter, filesystem edge cases. |

Optional fifth (manual, not in CI):

| Layer | Artifact | Purpose |
|---|---|---|
| End-to-end empirical | `assessments/qa-reports/YYYY-MM-DD-inbox-watch.md` | Live Evelynn and Sona dual-coordinator walkthrough; captures wall-clock latency + event text. Gates promotion `in-progress → implemented`. |

## 3. Test fixtures

Every test case constructs its own scratch tree under `$TMPDIR/inbox-
test-<pid>/` and exports `STRAWBERRY_AGENT=evelynn` (or `sona`) plus a
`REPO_ROOT_OVERRIDE` that the scripts under test must respect. Rakan's
implementation of `inbox-watch.sh` must accept either a `REPO_ROOT`
env var or `pwd`-based resolution; the test plan calls for `pwd`-based
resolution with `cd $SCRATCH` in the setup.

Standard fixture generators (helper functions Rakan will implement at
the top of the harness):

- `make_pending <dir> <name> [--from=S] [--prio=P] [--timestamp=T]` —
  writes a canonical pending message.
- `make_read <dir> <name> [--read-at=T]` — writes a read message
  (used only for legacy-migration and "never emit" tests).
- `make_archived <dir> <yyyy-mm> <name> [--mtime-days-ago=N]` — writes
  a file under `archive/<yyyy-mm>/` and backdates mtime via `touch
  -t`. Use `touch -t` on BSD (macOS) and `touch -d` on GNU (Linux) —
  the helper detects which is available.
- `corrupt_frontmatter <path>` — truncates the closing `---`, used for
  corrupt-frontmatter cases.

## 4. Unit battery — `inbox-watch.test.sh` (I1, I2, I3, I4, I5, I6, I8, I11, I13)

XFAIL marker: `# XFAIL: scripts/hooks/inbox-watch.sh not yet implemented`.
Harness pattern identical to `scripts/hooks/tests/pre-compact-gate.test.sh`
(committed reference) — test file exits 0 and reports all cases as XFAIL
when the target script is missing.

### 4.1 Phase 1 emission cases

| Case | Fixture | Assertion |
|---|---|---|
| U-W-01 | Empty `inbox/` dir | stdout empty; exit 0; stderr empty. |
| U-W-02 | Single `status: pending` file | Exactly one stdout line; line matches regex `^INBOX: <name>\.md — from <sender> — <priority>$`; exit 0. |
| U-W-03 | N=10 pending files, varied senders + priorities | N lines, one per file; each matches line-format regex; no duplicates; order unspecified but deterministic within a run (document whatever order the impl picks, assert on the set via `sort`). |
| U-W-04 | Mix of pending + read files (flat) | Only the pending files produce `INBOX:` lines; the read files produce zero lines. (Covers I2, guards against re-emission of legacy `status: read` entries during the migration-boot window — see §8.) |
| U-W-05 | `archive/2026-04/foo.md` with `status: pending` (edge case — archive should never hold pending, but defend in depth) | Phase 1 does not emit a line for the archive entry; exit 0. Enforces I6. |
| U-W-06 | File without `status:` frontmatter key | Zero emission for that file; exit 0. |
| U-W-07 | File with `status: read` but **no** `read_at` | Zero emission; exit 0. (Belt-and-braces — legacy files have this shape.) |
| U-W-08 | File with `status:  pending ` (whitespace-padded) | One emission. Frontmatter parsing must be tolerant of surrounding whitespace. Call out to Rakan: prefer a single awk/sed parser over grep, to sidestep false-positive matches on body text. |
| U-W-09 | File that matches `*.md` but is **actually a directory** (edge) | Skipped silently; exit 0. (Defensive — a user may have a checked-out worktree subdir named `something.md/`.) |

### 4.2 Phase 0 cleanup cases (I5)

| Case | Fixture | Assertion |
|---|---|---|
| U-C-01 | `archive/2026-03/old.md` mtime 10 days ago + `archive/2026-04/fresh.md` mtime 1 hour ago | After run: `old.md` gone, `fresh.md` present, `archive/2026-03/` pruned (empty), `archive/2026-04/` retained. |
| U-C-02 | `archive/2026-03/a.md` (10 days) + `archive/2026-03/b.md` (1 hour) | After run: `a.md` gone, `b.md` present, `archive/2026-03/` retained (non-empty). |
| U-C-03 | No `archive/` dir at all | Phase 0 no-ops silently; stderr does **not** contain "No such file or directory" (the `2>/dev/null` redirect must absorb `find`'s error). Exit 0. |
| U-C-04 | `archive/` dir empty | Phase 0 no-ops; no files deleted; `archive/` retained. |
| U-C-05 | `archive/2026-03/old.md` mtime exactly 7 days (boundary) | File **not** deleted (POSIX `-mtime +7` is strictly *greater than* 7×24h). Guards against a silent off-by-one that would delete fresh files. |
| U-C-06 | Non-`.md` file under `archive/` (e.g., `archive/.DS_Store`) | Untouched by Phase 0 (the `-name '*.md'` filter). Directory pruning only fires when the dir ends up empty — so if `.DS_Store` keeps the dir populated, the dir survives. Document this as the intentional behavior. |
| U-C-07 | Phase 0 runs, then Phase 1 still executes | `INBOX_WATCH_ONESHOT=1` combined fixture: backdated archive file + one pending file in `inbox/`. Assert both (a) the backdated file is gone and (b) the `INBOX:` line for the pending file was emitted. Proves cleanup does not short-circuit the sweep. |

### 4.3 Opt-out cases (I4)

| Case | Fixture | Assertion |
|---|---|---|
| U-O-01 | `touch .no-inbox-watch`; pending file exists in inbox | Exit 0; stdout empty; **archive cleanup does not run** (verify with a backdated archive file still present after the run). |
| U-O-02 | `.no-inbox-watch` exists; no inbox dir at all | Exit 0 silently. |

### 4.4 Identity resolution cases (I8)

Each runs with the repo's `.claude/settings.json .agent` set (or stripped)
as appropriate for the case. Use a fixture `settings.json` in the scratch
repo root; do **not** mutate the real `.claude/settings.json`.

| Case | Env / config | Expected resolved identity |
|---|---|---|
| U-I-01 | `CLAUDE_AGENT_NAME=evelynn` + `STRAWBERRY_AGENT=sona` + settings.agent=caitlyn | evelynn (first wins) |
| U-I-02 | `STRAWBERRY_AGENT=sona` + settings.agent=caitlyn, `CLAUDE_AGENT_NAME` unset | sona |
| U-I-03 | only settings.agent=Evelynn (mixed case) | evelynn (case-insensitive match per ADR §3.2) |
| U-I-04 | none of the three sources | Exit 0, stdout empty. |
| U-I-05 | `CLAUDE_AGENT_NAME=nonexistent` + no `agents/nonexistent/` dir | Exit 0, stdout empty. (Unknown-agent short-circuit — ADR §5 item 7.) |

### 4.5 Line-format contract (I3, I13)

| Case | Fixture | Assertion |
|---|---|---|
| U-F-01 | Pending file with `priority: high` | Line exactly matches `^INBOX: <name>\.md — from <sender> — high$`; no trailing whitespace. |
| U-F-02 | Pending file with unusual but valid `priority: urgent-review` | Regex `^INBOX: [^ ]+\.md — from [^ ]+ — [a-z\-]+$` still matches. Document in the test comment that Rakan's regex must not be stricter than `[a-z\-]+`. |
| U-F-03 | Pending file with filename containing spaces (should not happen — `/agent-ops send` generates slug-safe names — but defensive) | Either the filename is single-token in the emitted line (i.e. impl rejects / renames spaces) **or** the line still parses by a quoted variant. Impl choice; test asserts whichever is specified, and that stdout is unambiguous. Open question O1 (see §10). |
| U-F-04 | Stdout hygiene: no lines outside the `INBOX:` prefix when running against a pure fixture with no errors | `grep -v '^INBOX: ' stdout | wc -l` equals 0. Guards I13 (no rogue debug output that would trip the Monitor noisy-kill). |

### 4.6 Phase 2 (live-watch) smoke — optional, time-bounded

Phase 2 is hard to unit-test without `fswatch`/`inotifywait` available on
the CI runner. Rakan's harness should include **one** optional case that:

- Starts `inbox-watch.sh` in the background (no `ONESHOT`) with a 5 s
  timeout.
- After 0.5 s, drops a new pending file into the inbox.
- Kills the watcher at 4 s.
- Asserts stdout contains one `INBOX:` line for the dropped file.

Skip (XFAIL) if neither `fswatch` nor `inotifywait` is on `PATH` — the
poll fallback's 3 s cadence makes this case flaky in CI. Document the
skip condition in the test file.

## 5. Unit battery — `inbox-watch-bootstrap.test.sh` (I4, I8, I10)

XFAIL marker: `# XFAIL: scripts/hooks/inbox-watch-bootstrap.sh not yet implemented`.
Bootstrap consumes stdin JSON per the Claude Code hook contract.

| Case | stdin payload | Expected |
|---|---|---|
| U-B-01 | `{"hook_event_name":"SessionStart","source":"startup"}` with `CLAUDE_AGENT_NAME=evelynn` | Exit 0; stdout is valid JSON with `hookSpecificOutput.hookEventName == "SessionStart"` and `additionalContext` containing the literal strings `Monitor`, `bash scripts/hooks/inbox-watch.sh`, and `/check-inbox`. |
| U-B-02 | `source: resume` | Exit 0; stdout empty (I10). |
| U-B-03 | `source: clear` | Exit 0; stdout empty (I10). |
| U-B-04 | `source: compact` | Exit 0; stdout empty (I10). |
| U-B-05 | `source: startup` + no identity resolvable | Exit 0; stdout empty. |
| U-B-06 | `source: startup` + `.no-inbox-watch` present | Exit 0; stdout empty (I4). |
| U-B-07 | Malformed JSON on stdin (`"not json"`) | Exit 0; stdout empty; no uncaught shell trace on stderr. |
| U-B-08 | Missing `source` field | Treat as not-startup; exit 0; stdout empty. Defensive default: on any doubt, do not emit the nudge. |
| U-B-09 | `source: startup` + `CLAUDE_AGENT_NAME=sona` (dual-coordinator parity) | Same shape as U-B-01 but the `additionalContext` description references `sona`'s inbox. (I8 parity — see §7.) |

## 6. Integration battery — `inbox-channel.integration.test.sh` (I1, I7, I9, I11, I12)

Driver: a scratch repo layout with both `agents/evelynn/` and
`agents/sona/`. Integration means running **the real scripts** end-to-end
rather than mocking.

### 6.1 Watcher-then-check-inbox flow (I1, I7, I11)

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-01 | Two pending files in `agents/evelynn/inbox/`, each with a `timestamp: 2026-04-21 14:23` frontmatter | (a) Run `inbox-watch.sh` with `ONESHOT=1`; capture stdout. (b) Run the `/check-inbox` skill's disposition logic against the same dir. | After (a): two `INBOX:` lines. After (b): `inbox/` has zero `*.md` files (archive/ subdir may exist); both originals now live at `archive/2026-04/<original-name>` with `status: read` and a valid ISO-8601 `read_at`. |
| IT-02 | Pending file with **no** `timestamp:` frontmatter | Run `/check-inbox` disposition. | File moves to `archive/<mtime-YYYY-MM>/<name>` (I11 fallback). Assertion captures the mtime's month from the fixture at setup time and compares. |
| IT-03 | Pending file with `timestamp: malformed-not-a-date` | Run `/check-inbox` disposition. | Either: archive path falls through to mtime (documented fallback), or skill refuses with a clean error and leaves the file in place. Impl choice; open question O2 (§10). Test asserts whichever is specified and that the inbox dir is not left half-mutated. |
| IT-04 | Filter discipline: run watcher in background (Phase 2), then run check-inbox, then kill watcher | Count `INBOX:` lines in stdout | Exactly one line per original pending file — the check-inbox frontmatter rewrite must **not** produce a second event (I7). |

### 6.2 Sender-side invariant (I9)

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-05 | Scratch repo | Invoke `/agent-ops send evelynn "ping"` (or its Bash equivalent) | The new file appears at `agents/evelynn/inbox/<name>.md` flat; **no** file is ever created under `archive/`; the frontmatter has `status: pending`. |
| IT-06 | Static grep in the `/agent-ops` skill body | grep for `archive` in the `send` subcommand block | Zero matches. Guards I9 at the source-code level (regression floor for the ADR §5 item 4). |

### 6.3 Concurrency (I12)

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-07 | One pending file | Invoke `/check-inbox` disposition twice in parallel (shell `&`, then `wait`) | Exactly one archive file at `archive/2026-04/<name>`; the "loser" invocation exits 0 (not an error) having detected the source-gone state; both end-state invariants hold. |
| IT-08 | Ten pending files | Five parallel `/check-inbox` runs | All ten files end up archived; no duplicates; no originals left behind; no extra files created anywhere. |

### 6.4 Dual-coordinator parity (dedicated for this plan)

The ADR is explicit about dual-coordinator parity (Evelynn + Sona). The
integration battery must demonstrate both agents work identically with a
single code path.

| Case | Setup | Run | Assertion |
|---|---|---|---|
| IT-09 | Fixture repo with both `agents/evelynn/inbox/*.md` and `agents/sona/inbox/*.md` populated; set `CLAUDE_AGENT_NAME=evelynn` | Run `inbox-watch.sh` ONESHOT | Only evelynn's pending files emit `INBOX:` lines. Zero lines reference sona filenames. |
| IT-10 | Same fixture; flip `CLAUDE_AGENT_NAME=sona` | Run `inbox-watch.sh` ONESHOT | Only sona's pending files emit; zero evelynn references. |
| IT-11 | Two separate scratch processes, one per coordinator, each running its own watcher concurrently | Drop a pending file into each inbox | Each process's stdout contains exactly the line for its own inbox. No cross-contamination. Guards the "two coordinators, same checkout" failure mode (ADR §6). |
| IT-12 | `inbox-watch-bootstrap.sh` stdin with `CLAUDE_AGENT_NAME=sona`; same with `evelynn` | Compare `additionalContext` outputs | Structurally identical (same template); differ only in the agent name and the path string. Guarantees no accidental Evelynn-only special-casing. |

## 7. Fault-injection battery — `inbox-channel.fault.test.sh` (I5, I6, I7, I12, I13)

### 7.1 Corrupt frontmatter

| Case | Setup | Assertion |
|---|---|---|
| FI-01 | `inbox/foo.md` with only `---\nfrom: sona\n` (no closing `---`, no status) | `inbox-watch.sh` ONESHOT: zero emission for that file; exit 0; stderr does not contain uncaught shell errors. |
| FI-02 | `inbox/foo.md` with binary garbage in the first 4 KB | Zero emission; exit 0; stderr may carry a one-line skip notice but must not abort the run. |
| FI-03 | `inbox/foo.md` is a zero-byte file | Zero emission; exit 0. |
| FI-04 | `inbox/foo.md` is a symlink pointing to a file outside the repo | Either follow the link and parse (document and assert), or skip. Open question O3 (§10). |
| FI-05 | Frontmatter with `status: pending` duplicated twice (first as `pending`, second as `read`) | Impl must pick one deterministic rule (first-wins or last-wins); test asserts whichever is specified and that the emission count matches. Recommend first-wins for YAML compatibility. |

### 7.2 Filesystem races

| Case | Setup | Assertion |
|---|---|---|
| FI-06 | `inbox/foo.md` exists at Phase 1 listing time but is deleted before frontmatter-read | Zero emission for that file; exit 0; no `cat: No such file` leak to stderr. |
| FI-07 | New file atomically moved into `inbox/` via `mv $TMP/new.md inbox/` during Phase 1 | Either emitted in Phase 1 (if listed before the mv completed) or picked up by Phase 2 (if after). Never both. Test allows the OR but forbids the both-emit outcome. |
| FI-08 | `inbox/` is deleted outright while watcher is in Phase 2 | Watcher exits with a logged stderr line; exit code is **nonzero** so Monitor surfaces the failure per ADR §3.2 "Lifecycle". Test asserts exit != 0 and that stderr contains a human-readable message. |
| FI-09 | Filesystem full during `/check-inbox` frontmatter rewrite (simulate via `ulimit -f 1` or a tiny tmpfs) | Rewrite fails; skill aborts; **original file is not deleted or moved** (I1's post-condition tolerates the failure — no half-archive state). Test asserts the original is still present with original frontmatter. |

### 7.3 Concurrent watcher + check-inbox (I7 hardening)

| Case | Setup | Assertion |
|---|---|---|
| FI-10 | Start watcher in Phase 2; then concurrently: (a) drop a new pending file, (b) immediately run `/check-inbox` | Exactly one `INBOX:` event for the file. The watcher does not produce a second event from the frontmatter rewrite (I7). The check-inbox terminal state matches IT-01. Repeat 20 times to shake out races. |
| FI-11 | Start watcher; run `/check-inbox` on a pre-existing pending file; observe the exact ordering of (event emit, frontmatter rewrite, file move) | Timeline is: emit → rewrite (pending→read) → mv. Watcher's kernel-event on the rewrite re-reads the file, sees `status: read`, and declines to re-emit. If on poll fallback, same logic. Assertion: total `INBOX:` lines = 1. |

### 7.4 Monitor stream loss / reconnect

The Monitor tool lives in the coordinator session, not in shell. We
cannot unit-test the Claude Code side, but we **can** test the watcher's
behaviour when its stdout pipe is broken (simulating Monitor being
killed by the noisy-monitor auto-kill or a session compact).

| Case | Setup | Assertion |
|---|---|---|
| FI-12 | Start watcher in Phase 2 piping stdout into `head -n 2` (closes the pipe after 2 lines) | After pipe closes, watcher receives `SIGPIPE` and exits. Exit code acceptable: 0 or 141 (SIGPIPE); stderr is empty or one-line. Crucially, the watcher does **not** spin in a tight retry loop (verify CPU-time usage stays bounded for 10 seconds after the pipe closes). |
| FI-13 | Kill watcher PID with SIGTERM mid-Phase-2 | Clean exit; no stray child processes (`fswatch`/`inotifywait` subprocess). Test uses `pgrep -P <watcher-pid>` to confirm no orphans after the watcher exits. Guards against the subtle "dead watcher, live inotifywait" bug class. |
| FI-14 | Restart the watcher after a kill: run ONESHOT, then start Phase 2, then another pending file drops | Restarted run emits exactly one line per current pending file on its sweep, then picks up new drops in Phase 2. Idempotent restart — ADR §3.3 accepts duplicate Monitor events on double-boot, so the test documents but does not forbid the duplicate sweep when a user restarts by hand. |

### 7.5 Archive-cleanup fault cases (I5 hardening)

| Case | Setup | Assertion |
|---|---|---|
| FI-15 | `archive/2026-03/` owned by a different user (simulate with `chmod 000`) | Phase 0 logs one line to stderr (permission denied absorbed by `2>/dev/null` per ADR §3.2 — so the assertion is actually **no stderr**), continues to Phase 1 without aborting. Note: if the `2>/dev/null` swallows permission errors, we trade observability for resilience; Xayah accepts this tradeoff per ADR. |
| FI-16 | Clock skew: file mtime set **in the future** (e.g. `touch -t 203012310000 archive/2026-03/future.md`) | `find -mtime +7` does not match future-dated files → file survives. Test asserts no deletion. Rationale: clock skew is common on laptops after sleep; the tool must not delete "tomorrow"'s file. |
| FI-17 | Huge archive (1000 files under `archive/2026-03/`, half stale) | Phase 0 completes in < 2 seconds on a stock macOS laptop; all 500 stale files deleted; all 500 fresh files retained. Documents the expected performance envelope per ADR §4.3 ("Catch-up is O(n) over the archive tree, and the tree is small"). |

## 8. Migration assertions (first-boot parity with the existing Evelynn inbox)

**Discovered during fact-check**: today `agents/evelynn/inbox/` contains
131 `status: pending` files and 198 `status: read` files, all flat (no
`archive/` subdir at the time of this writing). The ADR's "pending-only
invariant" is a post-condition the system must *establish*, not a
pre-condition it can assume.

This is the highest-leverage test bucket Xayah adds beyond the ADR's
explicit acceptance criteria. Failing any of these on the first real
boot after merge would either spam the coordinator with 131 `INBOX:`
events or silently lose 198 historical messages. Both outcomes are
unacceptable.

### 8.1 Migration contract the implementation must satisfy

Rakan's implementation commit for the watcher + skill must **also**
include a one-shot migration step (call it `scripts/hooks/inbox-migrate.sh`
<!-- orianna: ok --> or equivalent) that runs once, idempotently, to:

1. For every flat `inbox/*.md` with `status: read`: move it to
   `archive/<YYYY-MM>/<name>`. If it has no `read_at`, synthesise one
   from file mtime or use `1970-01-01T00:00:00Z` as a sentinel (impl
   choice; open question O4 §10).
2. Leave every `status: pending` file in place.
3. Emit a one-line summary to stderr: `migrated N read files, left M
   pending`.

This migration must happen **before** the first watcher boot on a repo
with legacy data, otherwise the first Phase 1 sweep emits 131+ `INBOX:`
events — violating ADR §4.3 (low volume expected) and potentially
tripping the Monitor noisy-kill. Xayah's position: the migration is a
hard requirement, not an optional polish.

### 8.2 Migration test cases — belong in the integration battery

File: `scripts/hooks/tests/inbox-channel.integration.test.sh`
<!-- orianna: ok --> (case range `MIG-*`).

| Case | Setup | Run | Assertion |
|---|---|---|---|
| MIG-01 | Fixture mirroring real Evelynn state: 131 pending + 198 read files flat in `inbox/`, no `archive/` | Run migration script once | After: `inbox/` contains exactly 131 `*.md` files (all `status: pending`); `archive/<YYYY-MM>/` contains 198 files; frontmatter of each archived file has `status: read` and either a preserved or synthesised `read_at`. Exit 0. |
| MIG-02 | Same fixture | Run migration script **twice** | Second run is a no-op (`migrated 0 read files, left 131 pending`); end-state identical to MIG-01. Idempotence. |
| MIG-03 | Post-migration state from MIG-01 | Run `inbox-watch.sh` ONESHOT | Exactly 131 `INBOX:` lines emitted; zero lines reference archived files. Guards the I2 invariant under real legacy volume. |
| MIG-04 | Migration aborted mid-way (e.g. SIGTERM after 50 files) | Restart migration | Final state is correct; no duplicated archive entries; no lost files. Requires the migration to use atomic `mv` per file, which it does by default on same-filesystem. |
| MIG-05 | Pre-migration grep count against the real repo (as a one-time audit step, run manually) | `ls -1 agents/evelynn/inbox/*.md | wc -l` vs. `grep -lE '^status: pending' agents/evelynn/inbox/*.md | wc -l` | Document the live counts at merge time in the PR body and archive them in the QA report (§2 E2E artifact). Diff before/after migration to prove no file was lost. |

### 8.3 Non-disturbance assertion

| Case | Assertion |
|---|---|
| MIG-06 | After migration, every surviving pending file in `inbox/` is byte-identical to its pre-migration state (content hash unchanged). Migration only reads frontmatter and moves read files — it never rewrites pending content. |
| MIG-07 | `.no-inbox-watch` at migration time: migration **still runs** (opt-out is for the watcher, not the one-shot migration). Rationale: without migration, re-enabling the watcher later would spam 131+ events. Document this decision and assert it explicitly. |

## 9. Regression-floor battery (runs in every battery; static checks)

Mirrors ADR §5 items 9, 10 and the test-plan block at the ADR's bottom.

| Check | Command (conceptual) | Expected |
|---|---|---|
| R-01 | `grep -r 'strawberry-inbox' .claude/plugins` | no matches (dir absent) |
| R-02 | `grep -rE 'channelsEnabled|--channels|development-channels' scripts/ .claude/` | no matches |
| R-03 | `find . -name '.mcp.json' -path '*/strawberry-inbox/*'` | no matches |
| R-04 | `grep -rn 'UserPromptSubmit' .claude/settings.json` | no entry naming inbox-nudge / inbox-watch |
| R-05 | `test ! -f scripts/hooks/inbox-nudge.sh` | file absent |
| R-06 | `grep -rn 'pending message(s)\. Run /check-inbox to read them\.' scripts/hooks/` | no matches (v2 phrasing fingerprint) |
| R-07 | `grep -rn 'agents/.*/inbox/archive' .claude/skills/agent-ops/` | no matches (I9 code-level regression) |
| R-08 | Sender-side: `/agent-ops send` step list in `SKILL.md` does not reference `archive/` | document match absence |

These run at the top of every harness file so a missing/stray file trips
all batteries at once.

## 10. Open questions / blocking items

Xayah flags for ADR author's (Azir's) confirmation before Rakan
implements. None of these block writing the tests, but impl must choose
deterministically so assertions aren't ambiguous.

- **O1** — Filename with spaces: should `/agent-ops send` reject, slug-
  ify, or pass through? Test asserts whichever; recommend slugify (same
  rule as commit-prefix hook filenames). Impacts U-F-03.
- **O2** — Malformed `timestamp:` frontmatter on archive: fall through to
  mtime-based month, or refuse? Recommend fall-through (matches §3.4
  step 3 "fallback: file mtime" wording). Impacts IT-03.
- **O3** — Symlink handling in `inbox/*.md`: follow or skip? Recommend
  skip (simpler; symlinks are not a documented creation path).
  Impacts FI-04.
- **O4** — Legacy `status: read` files lacking `read_at`: synthesise
  from mtime or use `1970-01-01T00:00:00Z` sentinel? Recommend mtime
  — preserves the actual "when" for humans browsing archive later.
  Impacts MIG-01.
- **O5** — Is the migration script (§8.1) part of the first-cut single
  commit per v3 table Q6, or a separate commit? Xayah's recommendation:
  same commit, because shipping the watcher without migration creates
  the 131-event spam hazard the moment the commit lands. Please confirm
  with Duong before Rakan implements.
- **O6** — Performance envelope for FI-17 (1000 archive files): < 2s is
  a guess. If the CI runner is slower, relax to < 10s. Rakan to tune.

## 11. CI and TDD posture

- No new CI jobs — all four test files plug into the existing
  pre-commit hook test harness (ADR §7 bottom).
- Each test file is committed **before** its target script per Rule 12,
  with the `XFAIL:` marker at the top. `pre-push-tdd.sh` recognises the
  marker and permits red.
- On the implementation commit that lands the scripts, the xfail marker
  is removed in the same commit; tests must then pass green. Rakan owns
  this transition.
- The fault-injection battery is **required** for merge; it is not an
  optional lint. The race in I7 and the resilience contract in FI-12/13
  are where real bugs hide.

## 12. Handoff

- **To Rakan**: implement the four `.test.sh` files above as xfail
  skeletons, one commit per file, each referencing its case range.
  Then implement the scripts + skill per the ADR and flip the tests
  green. Open questions O1–O6 get pinged to Azir (plan author)
  before green-flip.
- **To Duong**: please rule on O5 (migration in first cut vs separate)
  — this is the one open question with cross-cutting consequences.
- **Audit cadence**: Xayah re-reviews Rakan's PR before merge,
  specifically checking (a) the fault-injection cases are not stubbed
  out, (b) MIG-01 uses the real live file counts recorded in the QA
  report, (c) I7 has its 20-iteration race harness.

---

<!-- orianna: ok --> prospective paths recap:
- `scripts/hooks/tests/inbox-watch.test.sh`
- `scripts/hooks/tests/inbox-watch-bootstrap.test.sh`
- `scripts/hooks/tests/inbox-channel.integration.test.sh`
- `scripts/hooks/tests/inbox-channel.fault.test.sh`
- `scripts/hooks/inbox-migrate.sh` (if Azir/Duong confirm §8.1 / O5)
- `assessments/qa-reports/YYYY-MM-DD-inbox-watch.md` (manual E2E, gate
  for `in-progress → implemented`)
