---
slug: monitor-arming-gate-bugfixes
date: 2026-04-26
owner: karma
concern: personal
status: approved
tier: quick
complexity: normal
parallel_slice_candidate: no
tests_required: true
orianna_gate_version: 2
---

# Monitor-arming gate bugfixes — env leak, session-id fallback, post-compact migration

## Context

The PreToolUse Monitor-arming gate (`scripts/hooks/pretooluse-monitor-arming-gate.sh`) has three live bugs producing false-positive `INBOX WATCHER NOT ARMED` warnings on every coordinator-session tool call. All three were verified during Evelynn session 2026-04-26.

**Bug 1 — env-var leak to subagents.** The hook gates on `CLAUDE_AGENT_NAME` to scope the warning to coordinators (Evelynn / Sona). But `CLAUDE_AGENT_NAME=Evelynn` is exported in the coordinator shell and **leaks into Agent-tool-spawned subagents** that inherit the parent env. Subagents (Senna, Lucian, Kayn, etc.) consequently see `CLAUDE_AGENT_NAME=Evelynn`, fail the identity gate's "subagent exempt" branch, and trip the warning — leading to duplicate `inbox-watch.sh` Monitor spawns from each subagent that obeys the directive. PR #68 review notes captured this directly: "the inbox-watcher hook fired repeatedly throughout this session despite being a Senna subagent."

**Bug 2 — `CLAUDE_SESSION_ID` unset in coordinator shell.** Hook line 42 wraps the sentinel check in `if [ -n "$session_id" ]`. Verified live: `echo "${CLAUDE_SESSION_ID:-unset}"` returns `unset` in the Evelynn shell. Result: the sentinel branch is skipped entirely and the warning fires on every PreToolUse call even when `inbox-watch.sh` Monitor is healthy. The sentinel-arming PostToolUse hook has the same `[ -n "$session_id" ]` guard (`posttooluse-monitor-arm-sentinel.sh:50`), so when Claude Code does NOT export `CLAUDE_SESSION_ID` no sentinel is ever written and no sentinel is ever read — the gate degrades to "always fire."

**Bug 3 — post-compact sentinel orphaning.** The sentinel path embeds the session id: `/tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}`. After `/compact` the session id changes, but the original Monitor process (e.g. pid 60660) is still healthy and watching the inbox. The new session writes a new sentinel only if Duong remembers to re-arm; meanwhile the gate fires on every call until then. Even with Bug 2 fixed, a session-id-keyed sentinel cannot survive compact.

These are cross-process semantics (parent shell env → child subagent env, hook-shell env → process tree, pre-compact session → post-compact session), so the full quick-tier chain (Karma plan → Talon impl → Senna+Lucian dual review) is required regardless of LOC.

## Scope

In-scope:
- `scripts/hooks/pretooluse-monitor-arming-gate.sh` — identity check, sentinel-existence check, post-compact fallback.
- `scripts/hooks/posttooluse-monitor-arm-sentinel.sh` — sentinel write must use the same identity/session resolution as the gate to stay symmetric.
- `scripts/hooks/tests/test-monitor-arming-gate-stateless.sh` and `test-monitor-gate-coordinator-scoped.sh` — extended with three new xfail-first regression cases.

Out of scope:
- Reworking the coordinator-identity SessionStart hook.
- Replacing the sentinel mechanism with a different signalling primitive (e.g. file-lock on the watcher pid).
- Changing `inbox-watch-bootstrap.sh` semantics.

## Decision

**Bug 1 fix — distinguish coordinator-shell from inherited-env identity.** The gate must use a signal that does NOT leak via env inheritance. Two viable approaches; T1 picks (a):

- (a) **Coordinator-only sentinel file** — `inbox-watch-bootstrap.sh` (which runs only in coordinator SessionStart) writes `/tmp/claude-coordinator-shell-${PPID-or-tty}` keyed by something stable to the coordinator process. The gate consults that file in addition to `CLAUDE_AGENT_NAME`. Subagents have a different process tree → no match → silent exit.
- (b) Agent-default-isolation hook clears `CLAUDE_AGENT_NAME` from the spawned subagent env. Riskier — affects every other consumer of that env var.

T1 implements (a) with the sentinel keyed by the **controlling tty** (`tty` command output, or `$SSH_TTY`, or fallback to `$PPID`). Coordinator session bootstrap writes `/tmp/claude-coordinator-shell-$(tty | tr / _)`; the gate checks for this file's presence in addition to the env-var name match. Subagent bash invocations have a different (or no) tty → file absent → silent exit.

**Bug 2 fix — degrade to a non-id-keyed sentinel when `CLAUDE_SESSION_ID` is unset.** The gate already gracefully handles missing session id by skipping the sentinel branch; the bug is that this path leads to "always warn." Change: when `session_id` is empty, fall back to a **process-keyed sentinel** at `/tmp/claude-monitor-armed-tty-$(tty | tr / _)`. The PostToolUse arming hook writes BOTH the session-keyed and tty-keyed sentinels when arming, so either resolves to a hit. This also incidentally fixes Bug 3 for the common case (post-compact session in the same tty).

**Bug 3 fix — pid-of-watcher reverse check.** Even with the tty-keyed sentinel, an ironclad fix is: when neither sentinel is found, the gate scans for a live `inbox-watch.sh` process whose parent is the current coordinator's process tree (or, simpler: any live `inbox-watch.sh` whose tty matches the coordinator's tty). If found, exit silent and `touch` a fresh sentinel for the current session. This makes the gate self-healing across compact.

Combined: gate logic becomes (1) identity match on env-var name AND coordinator-shell sentinel; (2) sentinel hit on session-keyed OR tty-keyed; (3) pid-scan rescue creating a fresh sentinel; (4) otherwise emit warning.

## Tasks

### T1 — Add coordinator-shell sentinel; gate consults it for identity

- kind: impl
- estimate_minutes: 25
- files: `scripts/hooks/inbox-watch-bootstrap.sh`, `scripts/hooks/pretooluse-monitor-arming-gate.sh`
- detail: In the bootstrap (which only runs in coordinator SessionStart per `.claude/settings.json:48-52`), compute `tty_key="$(tty 2>/dev/null | tr '/' '_' | tr -d '\n' || echo no-tty-$$)"` and `touch "/tmp/claude-coordinator-shell-${tty_key}"`. In the gate, after the existing env-var name match (lines 27-35), additionally require `[ -f "/tmp/claude-coordinator-shell-${tty_key}" ]` for the same `tty_key`. If absent, silent exit 0. This blocks Bug 1: subagent processes spawned by Agent tool inherit `CLAUDE_AGENT_NAME` but run on a different tty (or none), so the file lookup misses.
- DoD:
  - Bootstrap writes the file on coordinator session start.
  - Gate exits silent when env-var matches but coordinator-shell sentinel is absent (verified by extended xfail test C1 below).
  - No regression in existing `test-monitor-arming-gate-stateless.sh` Test 4 (Sona must still warn — bootstrap runs for both Evelynn and Sona).

### T2 — Add tty-keyed sentinel fallback for unset CLAUDE_SESSION_ID

- kind: impl
- estimate_minutes: 20
- files: `scripts/hooks/pretooluse-monitor-arming-gate.sh`, `scripts/hooks/posttooluse-monitor-arm-sentinel.sh`
- detail: In the gate (lines 41-48), if `CLAUDE_SESSION_ID` is empty OR the session-keyed sentinel is absent, additionally check `/tmp/claude-monitor-armed-tty-${tty_key}`. In the PostToolUse arming hook (lines 49-55), when arming write BOTH `/tmp/claude-monitor-armed-${session_id}` (existing, when session_id present) AND `/tmp/claude-monitor-armed-tty-${tty_key}` (always). The tty-keyed sentinel is the durable one across compact and unset-session-id conditions.
- DoD:
  - Gate is silent when only the tty-keyed sentinel exists (xfail test C2 below).
  - Arming hook writes both sentinels on Monitor invocation of `inbox-watch.sh`.
  - Existing Test 3 (sentinel present + Evelynn → silent) still passes.

### T3 — Pid-scan rescue: detect live `inbox-watch.sh` in same tty and self-heal

- kind: impl
- estimate_minutes: 25
- files: `scripts/hooks/pretooluse-monitor-arming-gate.sh`
- detail: After the sentinel checks fail and before emitting the warning, run a portable process scan: `pgrep -f 'scripts/hooks/inbox-watch\.sh'` (or `ps -A -o pid,tty,command | awk` fallback for Git Bash). If a hit exists AND its tty matches the coordinator's tty, treat as armed: `touch` BOTH sentinels for the current session/tty and exit 0 silently. Cap the scan to one `pgrep` call (no loop). This rescues post-compact orphaned sessions (Bug 3) without requiring user action.
- DoD:
  - Gate self-heals when a live `inbox-watch.sh` matches the coordinator tty (xfail test C3 below).
  - Sentinels are written on rescue so subsequent calls take the cheap silent path.
  - No false-positive rescue when `inbox-watch.sh` runs in a different tty (e.g. another Claude window).

### T4 — Wire xfail-first regression tests (commit before T1-T3)

- kind: test
- estimate_minutes: 15
- files: `scripts/hooks/tests/test-monitor-arming-gate-stateless.sh` (extend), `scripts/hooks/tests/test-monitor-gate-coordinator-scoped.sh` (extend)
- detail: Add the three new test cases described in the **Test plan** below. Each must reference this plan slug in a comment. Tests must be committed first on the implementation branch as red/xfail (Rule 12). After T1-T3 land, the same tests turn green.
- DoD:
  - All three new tests committed in their xfail-red state in a commit prior to any T1-T3 implementation commit on the same branch.
  - tdd-gate.yml CI shows the xfail commit ahead of the impl commit.

## Test plan

xfail-first per Rule 12. Tests below MUST be committed red before any implementation commit on the impl branch. Each protects one of the three live bugs.

**Test C1 — Bug 1 (env-leak): subagent identity must be inferable without trusting `CLAUDE_AGENT_NAME` alone.**
- Location: extend `test-monitor-arming-gate-stateless.sh`.
- Setup: write `/tmp/claude-coordinator-shell-<tty_key>` for one tty value; invoke gate with `CLAUDE_AGENT_NAME=Evelynn` but a DIFFERENT `tty_key` env override (simulating subagent on different tty).
- Expect: gate exits silent (empty stdout). On HEAD: gate emits warning → fail (xfail). After T1: pass.
- Invariant protected: subagents inheriting `CLAUDE_AGENT_NAME=Evelynn` must NOT trip the gate.

**Test C2 — Bug 2 (unset session id): tty-keyed sentinel must silence the gate.**
- Location: extend `test-monitor-arming-gate-stateless.sh`.
- Setup: leave `CLAUDE_SESSION_ID` unset; create `/tmp/claude-monitor-armed-tty-<tty_key>`; create the coordinator-shell sentinel for the same tty; invoke gate with `CLAUDE_AGENT_NAME=Evelynn`.
- Expect: silent. On HEAD: warning fires (sentinel branch is skipped because `session_id` empty). After T2: pass.
- Invariant protected: gate must not depend on `CLAUDE_SESSION_ID` being set.

**Test C3 — Bug 3 (post-compact rescue): live `inbox-watch.sh` on same tty must self-heal.**
- Location: extend `test-monitor-gate-coordinator-scoped.sh` OR new file `test-monitor-arming-gate-rescue.sh` <!-- orianna: ok -->.
- Setup: spawn a sleep stub renamed/symlinked to mimic `inbox-watch.sh` in the controlling tty (or stub the `pgrep` result via `PATH` shimming with a fake `pgrep` that prints a matching line). Ensure NO sentinel files exist. Invoke gate with `CLAUDE_AGENT_NAME=Evelynn` and the coordinator-shell sentinel present.
- Expect: silent stdout AND both `/tmp/claude-monitor-armed-${session_id}` (if session id set) and `/tmp/claude-monitor-armed-tty-<tty_key>` exist after the call. On HEAD: warning fires (no rescue logic). After T3: pass.
- Invariant protected: a healthy Monitor process across `/compact` must not produce phantom warnings.

Pre-existing tests (Tests 1-5 in `test-monitor-arming-gate-stateless.sh`, scope loop in `test-monitor-gate-coordinator-scoped.sh`) MUST continue to pass. Notably Test 4 (Sona warns when sentinel absent) requires the coordinator-shell sentinel to be present — bootstrap fixture must arm both Evelynn and Sona scenarios.

## Done-when

- [ ] T4 xfail tests committed red on impl branch (commit precedes T1-T3 commits).
- [ ] T1 lands; C1 turns green; existing Tests 1-5 still pass.
- [ ] T2 lands; C2 turns green; sentinel symmetry holds (PostToolUse writes both keys).
- [ ] T3 lands; C3 turns green; pid-scan does not match across-tty processes.
- [ ] In a live Evelynn session: spawning a Senna or Lucian subagent does NOT cause the subagent to receive the `INBOX WATCHER NOT ARMED` directive (manual smoke).
- [ ] In a live Evelynn session post-`/compact`: gate is silent within the first three tool calls when the pre-compact `inbox-watch.sh` is still running (manual smoke).
- [ ] Senna + Lucian dual review approve; PR is green; no `--admin` merge (Rule 18).

## References

- Hook source: `scripts/hooks/pretooluse-monitor-arming-gate.sh`
- Sentinel writer: `scripts/hooks/posttooluse-monitor-arm-sentinel.sh`
- Bootstrap: `scripts/hooks/inbox-watch-bootstrap.sh`
- Wiring: `.claude/settings.json` PreToolUse catch-all (lines 108-115) and PostToolUse Monitor matcher (lines 145-153).
- Existing tests: `scripts/hooks/tests/test-monitor-arming-gate-stateless.sh`, `scripts/hooks/tests/test-monitor-gate-coordinator-scoped.sh`.
- INV-3 origin: `plans/implemented/2026-04-24-coordinator-boot-unification.md` (T13/T14/T21).
- Live evidence (Bug 1): Senna PR #68 review notes; 12 duplicate `inbox-watch.sh` shells observed in Evelynn session 2026-04-26.
- Live evidence (Bug 2): `echo "${CLAUDE_SESSION_ID:-unset}"` → `unset` in coordinator shell, 2026-04-26.
- Live evidence (Bug 3): pid 60660 healthy after `/compact`, gate firing on every call.

## Orianna approval

- **Date:** 2026-04-26
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (Karma), concrete bug descriptions with live evidence for all three defects, and a decision section that justifies the chosen design (tty-keyed sentinel + pid-scan rescue) over the riskier env-clearing alternative. Tasks T1-T4 are actionable with files, estimates, and DoD. Test plan satisfies Rule 12 (xfail-first) with one regression test per bug, and pre-existing tests are explicitly preserved. Done-when includes manual smoke checks for the cross-process semantics that unit tests cannot fully cover.
