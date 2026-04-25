---
title: Fix coordinator identity env leak and inbox-watcher subprocess propagation
slug: 2026-04-25-coordinator-identity-leak-watcher-fix
date: 2026-04-25
owner: karma
status: approved
concern: personal
complexity: quick
orianna_gate_version: 2
tdd_required: true
tests_required: true
risk: medium
related:
  - plans/in-progress/2026-04-20-strawberry-inbox-channel.md
  - scripts/hooks/inbox-watch.sh
  - scripts/hooks/inbox-watch-bootstrap.sh
  - scripts/hooks/sessionstart-coordinator-identity.sh
  - scripts/coordinator-boot.sh
  - scripts/mac/launch-evelynn.sh
  - scripts/mac/launch-sona.sh
---

## Background

Two coupled problems surfaced when this Evelynn session was mis-pinned as Sona on resume because `STRAWBERRY_AGENT=sona` was leaking from the parent shell of a prior verification/probe.

**Problem A — env-var leakage to parent shell.** The two coordinator launch paths today are: (1) `bash scripts/coordinator-boot.sh <Name>` (via the `evelynn`/`sona` aliases in `scripts/mac/aliases.sh`) and (2) the helper scripts `scripts/mac/launch-evelynn.sh` / `launch-sona.sh`. The aliases run via `bash ...`, so the subshell-scoped exports cannot reach the parent — that path is fine. The leak channel is the helper scripts (and any ad-hoc verification command that does `export STRAWBERRY_AGENT=...` directly), which on `source` or copy-paste persist in the interactive shell. After `/exit` the next `claude` invocation inherits the stale identity, and the SessionStart hook's Tier 1 env-var resolution trusts it.

**Problem B — watcher identity propagation.** `scripts/hooks/inbox-watch.sh` resolves identity from `CLAUDE_AGENT_NAME` / `STRAWBERRY_AGENT` only. When Monitor spawns the watcher, the bash subprocess inherits whatever Claude inherited. With the current export-leak channel this works by accident; any "cleaner" launcher that sets identity inside the Claude process only (e.g. `--agent` flag without env export) breaks the watcher silently — it fails identity resolution, exits 0 with empty stdout, and Duong gets no inbox events. Yuumi commit `240bd394` (now reverted) shipped exactly this regression with no test coverage.

**Why a corrective plan now.** The Yuumi fix bypassed the gate chain (Karma → Orianna → Talon → Senna+Lucian) as a "surgical" direct commit and broke production silently. This plan is the corrective: it solves both problems together with explicit regression coverage for the failure modes we just observed, and it ships through the full gate.

## Decision

Two-pronged fix anchored on the existing `.coordinator-identity` hint file (already written by `/pre-compact-save`, already consumed by `sessionstart-coordinator-identity.sh` as Tier 2):

1. **Eliminate the leak channel at the source.** Rewrite `scripts/mac/launch-evelynn.sh` and `launch-sona.sh` to use the same subshell-isolated pattern as the aliases — the script body becomes a single `bash` invocation (or wraps the exports in `( ... ; exec claude )`) so even when `source`d the exports remain scoped. Same change for the `.bat` and `.ps1` Windows variants where applicable (PowerShell: use `& { ... }` script block; cmd: use a child `cmd /c`). The aliases path is already correct and stays as-is.

2. **Make watcher identity resolution defence-in-depth.** Add `.coordinator-identity` as a Tier 3 fallback inside `inbox-watch.sh` and `inbox-watch-bootstrap.sh`, mirroring the SessionStart hook's chain. The launcher is updated to write `.coordinator-identity` (atomically, via tmp+mv) before `exec claude`, so the file is the canonical identity source for any subprocess Monitor or future hooks spawn — independent of whether env vars propagate. Env vars remain Tier 1 (no behaviour change for working setups); the hint file becomes a reliable Tier 2/3 across the watcher and the SessionStart hook.

3. **Bootstrap fires on resume too.** `scripts/hooks/inbox-watch-bootstrap.sh` currently early-exits unless `source=startup`. Extend the gate to `startup|resume|clear|compact` so the watcher is re-armed after every session resume, not only fresh starts. This closes the live failure mode where pending inbox messages are invisible on a resumed session until Duong manually nudges Monitor.

Rejected alternatives:

- **Re-export inside Claude (`exec env VAR=val claude` plus a per-process re-export).** Cleaner in theory, but Claude's process model does not let us reliably re-export to arbitrary Monitor-spawned subprocesses without additional wrapping; testing surface is large; we would still want the hint file as a backup. The chosen approach gets us the same resilience with a smaller change.
- **Drop env vars entirely, file-only.** Breaks every existing hook that reads env vars (subagent-denial-probe, gh-audit-log) and every external workflow that relies on them. Too wide a blast radius for the quick lane.

## Tasks

1. **Add Tier 3 file fallback to `inbox-watch.sh`.**
   - kind: code
   - estimate_minutes: 15
   - files: `scripts/hooks/inbox-watch.sh`
   - detail: After the existing env-var resolution block (lines ~51-57), add a third tier that reads `$REPO/.coordinator-identity` if `coord` is still empty. Lowercase + trim whitespace, validate against `evelynn|sona`, set `coord` if valid. Preserve fail-loud stderr line when all three tiers miss.
   - DoD: New tier compiles under `set -eu`; existing env-var paths unchanged; new-tier behaviour exercised by Task 5 test 2.

2. **Add Tier 3 file fallback to `inbox-watch-bootstrap.sh`.**
   - kind: code
   - estimate_minutes: 10
   - files: `scripts/hooks/inbox-watch-bootstrap.sh`
   - detail: Mirror Task 1 — third tier reading `.coordinator-identity` after env vars, same validation, same lowercase normalisation. Place it before the bootstrap-nudge JSON emission.
   - DoD: Resume-with-empty-env + valid hint file emits the bootstrap nudge.

3. **Extend bootstrap source gate to resume|clear|compact.**
   - kind: code
   - estimate_minutes: 5
   - files: `scripts/hooks/inbox-watch-bootstrap.sh`
   - detail: Replace the `if [ "$source_val" != "startup" ]; then exit 0; fi` guard with a positive allowlist: `case "$source_val" in startup|resume|clear|compact) ;; *) exit 0 ;; esac`. Nudge text stays identical — Monitor is idempotent on re-arm.
   - DoD: Bootstrap emits the nudge for all four source values; emits nothing for an unknown source.

4. **Subshell-isolate the helper launchers + write `.coordinator-identity`.**
   - kind: code
   - estimate_minutes: 25
   - files: `scripts/mac/launch-evelynn.sh`, `scripts/mac/launch-sona.sh`, `scripts/windows/launch-evelynn.bat`, `scripts/windows/launch-sona.bat`, `scripts/windows/launch-sona.ps1`, `scripts/coordinator-boot.sh`
   - detail: (a) In each `.sh` launcher, wrap the `export ...; exec claude` block in a subshell `( export ...; printf '%s' "<Name>" > "$REPO_DIR/.coordinator-identity.tmp" && mv "$REPO_DIR/.coordinator-identity.tmp" "$REPO_DIR/.coordinator-identity"; exec claude ... )` so even if the script is sourced the exports do not survive. (b) Add the same atomic write of `.coordinator-identity` (canonical-case `Evelynn`/`Sona`) inside `coordinator-boot.sh` immediately after the existing exports — the alias path stays subshell-safe via `bash`, this just guarantees the hint file is fresh on every boot. (c) PowerShell: wrap the body in `& { ... }`; cmd `.bat`: spawn `cmd /c` for the inner block. Hint-file write in PowerShell uses `Set-Content` to a tmp + `Move-Item`.
   - DoD: After running any launcher and exiting Claude, `echo $STRAWBERRY_AGENT` in the parent shell is empty; `.coordinator-identity` contains the canonical name.

5. **Test plan implementation (xfail-first).**
   - kind: test
   - estimate_minutes: 35
   - files: `scripts/tests/test-coordinator-identity-leak.sh` <!-- orianna: ok -->, `scripts/tests/test-inbox-watch-tier3.sh` <!-- orianna: ok -->, `scripts/tests/test-bootstrap-resume-sources.sh` <!-- orianna: ok -->
   - detail: Author the four regression tests below as POSIX bash scripts, committed as xfail BEFORE Tasks 1-4 land on the same branch (Rule 12). Each test is self-contained, uses a `mktemp -d` sandbox, and asserts via `[ "$expected" = "$actual" ] || exit 1`. Wire into `scripts/tests/run-all.sh` if such a runner exists; otherwise add a top-level `make test-coordinator-identity` style entry point.
   - DoD: All four tests fail before Tasks 1-4, pass after.

6. **Document the gate-bypass lesson.**
   - kind: docs
   - estimate_minutes: 5
   - files: `agents/karma/learnings/2026-04-25-watcher-leak-gate-bypass.md` <!-- orianna: ok -->
   - detail: One-page learning capturing: (a) the env-var leak that mis-pinned Evelynn as Sona, (b) the Yuumi `240bd394` direct-commit that broke the watcher silently, (c) the corrective gate path (Karma → Orianna → Talon → Senna+Lucian), (d) the architectural lesson — any change to identity resolution must include subprocess-propagation tests because Monitor inherits Claude's env, not the launcher's.
   - DoD: Learning committed alongside the implementation PR.

## Test plan

Four explicit regression cases, mapped to the failure modes from this incident:

- **Test 1 — no parent-shell leak after launcher exit.** In a clean subshell, run `bash scripts/mac/launch-evelynn.sh &` (mocked `exec claude` to a no-op `true`), wait for exit, then assert `[ -z "${STRAWBERRY_AGENT:-}" ]` and `[ -z "${CLAUDE_AGENT_NAME:-}" ]` in the parent. Protects INV: launcher identity must not survive the launcher process.
- **Test 2 — Monitor-spawned watcher resolves identity without env.** With `unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME` and `.coordinator-identity` containing `Evelynn`, run `INBOX_WATCH_ONESHOT=1 bash scripts/hooks/inbox-watch.sh` against a fixture inbox containing one `status: pending` message. Assert stdout contains exactly one `INBOX:` line. Protects: watcher must work when launcher pins identity via file, not env.
- **Test 3 — bootstrap fires on resume.** Pipe `{"source":"resume"}` into `bash scripts/hooks/inbox-watch-bootstrap.sh` with valid identity (env or file). Assert stdout is non-empty JSON containing `"hookEventName":"SessionStart"`. Repeat for `clear`, `compact`, `startup`. Protects: pending inbox messages on a resumed session must surface without manual nudge.
- **Test 4 — SessionStart identity stable across resume.** Set `STRAWBERRY_AGENT=Evelynn` and write `.coordinator-identity=Evelynn`, run the SessionStart hook with `{"source":"resume"}`, capture additionalContext, assert it pins `Evelynn`. Then unset env (simulating a clean parent shell after our leak fix) and re-run — assert it still pins `Evelynn` from the hint file. Protects: launcher-pinned identity survives env-leak elimination.

All four tests run in the pre-commit unit-test phase per Rule 14.

## Open questions

- None blocking. (One non-blocking nit: the `.bat` subshell pattern is uglier than the bash one; if Duong does not actively use the Windows `.bat` launcher we can mark it TODO and ship the `.sh` + `.ps1` paths in this PR. Default assumption: ship all platforms.)

## References

- `plans/in-progress/2026-04-20-strawberry-inbox-channel.md` — original inbox channel design (§3.2 watcher, §3.3/§3.5 bootstrap)
- Reverted commit `240bd394` (Yuumi) — the silent-break that motivates the test plan
- Universal invariants 4, 12, 14 in `CLAUDE.md`

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (karma), concrete tasks with files/estimates/DoD, and a four-case regression test plan that maps directly to the two failure modes (env leak, watcher subprocess identity loss) plus the resume-source bootstrap gap. Rule 12 xfail-first ordering is explicit in Task 5. Rejected alternatives are documented and the scope is appropriately narrow. The lone non-blocking nit on Windows `.bat` subshell wrapping is acknowledged in Open Questions and may be downgraded to a TODO at Talon's discretion without reblocking.
