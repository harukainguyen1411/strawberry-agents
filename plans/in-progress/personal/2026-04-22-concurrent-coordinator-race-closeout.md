---
status: in-progress
concern: personal
owner: karma
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
tests_required: true
tags: [concurrency, git, locks, orianna, plan-lifecycle]
related:
  - plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md
  - plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md
  - plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md
  - agents/evelynn/inbox/archive/2026-04/2026-04-22-bash-cwd-wedge-feedback.md
architecture_changes: [architecture/key-scripts.md]
---

# Concurrent coordinator race closeout — flock the signing/promote commit window + auto-scope

## Context

Evelynn and Sona share one working tree. Today produced three concurrency
failures: (1) `git mv` inside `scripts/plan-promote.sh` raced the harness cwd
preflight and wedged a session; (2) concurrent `git add`/`git commit` on the
shared index produced commit `252e024` where one agent's commit message
landed on another agent's staged diff; (3) plan-promote commits kept getting
blocked by parallel-staging races, forcing manual `git restore --staged`
recovery. The common root cause for (2) and (3) is an unprotected
staging-to-commit window inside `scripts/orianna-sign.sh` and
`scripts/plan-promote.sh`. The cwd-cache bug (1) is upstream Claude Code
(issue #51885) and is out of scope here.

Partial mitigation already shipped: `STAGED_SCOPE` (PR #20 / `e7189281`) lets
`scripts/orianna-sign.sh` pathspec-scope its commit. `scripts/plan-promote.sh`
exports it but orianna-sign is invoked by Orianna herself *before*
plan-promote runs — the export in plan-promote is unreachable for the signing
call (Senna's finding). `scripts/plan-promote.sh` also has its own flock on
`.plan-promote.lock` <!-- orianna: ok -- runtime lockfile, never a tracked path -->, but `scripts/orianna-sign.sh` does
not, so two concurrent signing invocations can still race the index.

This plan closes both gaps: advisory flock on a shared lockfile for both
scripts covering the full `git add` → `git commit` window, plus an auto-derive
for `STAGED_SCOPE` inside `scripts/orianna-sign.sh` when unset (making the contract
self-sufficient regardless of caller).

## Decision

- Shared lockfile: `.git/strawberry-promote.lock` <!-- orianna: ok -- runtime lockfile under .git/, never tracked -->
  (inside `.git/`, never tracked, scoped per-repo). <!-- orianna: ok -- dir token, not a tracked path --> Both scripts acquire it
  via flock with mkdir fallback, matching the existing
  `scripts/plan-promote.sh` pattern.
- `scripts/orianna-sign.sh` auto-derives `STAGED_SCOPE="$PLAN_REL"` when the
  variable is unset. Explicit caller-set values still win. Closes Senna's
  "unreachable export" finding without reshaping the call graph.
- The existing adoption plan
  (`plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md`) is
  orthogonal — it teaches executor agents (Yuumi, Ekko, etc.) to set
  `STAGED_SCOPE` before their own commits. This plan only covers the
  orianna-sign/plan-promote pair. Not absorbed; cross-referenced.

## Out of scope (flagged)

- Worktree-per-coordinator structural split (Swain territory if lock-based
  serialisation proves insufficient under sustained parallel load).
- Claude Code cwd-cache harness bug (upstream issue #51885).
- Rename-aware pre-lint
  (`plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md`) — unblocks
  automatically once STAGED_SCOPE adoption completes; no action needed here.

## Tasks

1. **xfail test: orianna-sign acquires lock** — `kind: test`, `estimate_minutes: 15`.
   Write `scripts/__tests__/test-orianna-sign-lock.sh` <!-- orianna: ok -- prospective test file, not yet created --> exercising two
   concurrent `scripts/orianna-sign.sh` <!-- orianna: ok -- existing script --> invocations against a temp repo; assert the
   second fails fast with a "already running (pid ...)" message rather than
   racing the index. Marked xfail until T3 lands. <!-- orianna: ok -- T1 xfail marker, implementation pending -->

2. **xfail test: plan-promote + orianna-sign share the lock** — `kind: test`,
   `estimate_minutes: 15`. Write `scripts/__tests__/test-coordinator-lock-shared.sh` <!-- orianna: ok -- prospective test file, not yet created -->
   starting `scripts/orianna-sign.sh` <!-- orianna: ok -- existing script --> with a stubbed slow `claude` and attempting a
   concurrent `scripts/plan-promote.sh` <!-- orianna: ok -- existing script --> on an unrelated plan; assert the promote
   blocks on the shared lock and completes cleanly once signing finishes.
   xfail until T3 + T4 land. <!-- orianna: ok -- T2 xfail marker, implementation pending -->

3. **Factor lock helper into shared lib** — `kind: refactor`,
   `estimate_minutes: 20`. Extract the existing flock-with-mkdir-fallback
   block from `scripts/plan-promote.sh` (lines 60-113) into
   `scripts/_lib_coordinator_lock.sh` <!-- orianna: ok -- prospective shared lib, not yet created --> exposing
   `coordinator_lock_acquire <lockfile>` and
   `coordinator_lock_release`. Preserve current behavior: flock first, mkdir
   fallback, PID body, trap-based cleanup, fast-fail with holder-pid message.
   Files: `scripts/_lib_coordinator_lock.sh` <!-- orianna: ok -- prospective shared lib, not yet created --> (new),
   `scripts/plan-promote.sh`. DoD: `scripts/plan-promote.sh` <!-- orianna: ok -- existing script --> sources the helper; T1
   still xfail (orianna-sign not yet wired); existing plan-promote smoke
   tests pass.

4. **Wire lock into orianna-sign.sh** — `kind: feat`,
   `estimate_minutes: 20`. In `scripts/orianna-sign.sh`, <!-- orianna: ok -- existing script --> source
   `scripts/_lib_coordinator_lock.sh` <!-- orianna: ok -- prospective shared lib, not yet created --> and call `coordinator_lock_acquire
   "$REPO_ROOT/.git/strawberry-promote.lock"` <!-- orianna: ok -- runtime lockfile, not tracked --> immediately before the
   `git -C "$REPO_ROOT" add "$PLAN_PATH"` line (currently ~L355). Trap-based
   release on EXIT/INT/TERM. Also switch `scripts/plan-promote.sh` <!-- orianna: ok -- existing script --> to use the same
   `.git/strawberry-promote.lock` <!-- orianna: ok -- runtime lockfile, not tracked --> path (migrate from `.plan-promote.lock` in
   repo root to keep lockfile out of the worktree). DoD: T1 + T2 pass; T2
   shared-lock contention verified; no leftover lockfile after normal exit.

5. **Auto-derive STAGED_SCOPE in orianna-sign.sh** — `kind: feat`,
   `estimate_minutes: 10`. In `scripts/orianna-sign.sh`, just before the
   existing `if [ -n "${STAGED_SCOPE:-}" ]` block (~L385), add:
   `: "${STAGED_SCOPE:=$PLAN_REL}"` and `export STAGED_SCOPE`. Existing
   validation (`case /*`, file-exists check) still runs. Update the log line
   to note "auto-derived" when the default was applied. DoD: running
   `orianna-sign.sh <plan> <phase>` with no STAGED_SCOPE in env produces a
   path-scoped commit as though the caller had set STAGED_SCOPE=<plan>.

6. **Remove dead export in plan-promote.sh** — `kind: chore`,
   `estimate_minutes: 5`. In `scripts/plan-promote.sh`, <!-- orianna: ok -- existing script --> remove the
   `export STAGED_SCOPE="$DEST_REL"` / matching `unset` pair (lines 313-320,
   338-340). The export is unreachable because plan-promote does not invoke
   orianna-sign; T5 makes the derivation self-sufficient inside
   `scripts/orianna-sign.sh`. <!-- orianna: ok -- existing script --> Leave a 2-line comment at the former location pointing
   to T5 for archaeology. Files: `scripts/plan-promote.sh`. <!-- orianna: ok -- existing script -->

7. **Docs update in key-scripts.md** — `kind: docs`,
   `estimate_minutes: 10`. Update `architecture/key-scripts.md`: (a) add
   `scripts/_lib_coordinator_lock.sh` <!-- orianna: ok -- prospective shared lib, not yet created --> row under the "Orianna Signing
   Scripts" table or a new "Shared libraries" subsection; (b) rewrite the
   existing `STAGED_SCOPE` subsection (L49-65) to state the auto-derive
   default and remove the stale "plan-promote.sh exports it automatically"
   claim; (c) add a one-paragraph "Coordinator lock contract" subsection
   naming `.git/strawberry-promote.lock`, <!-- orianna: ok -- runtime lockfile, not tracked --> the two scripts that acquire it,
   and the fast-fail semantics. Files: `architecture/key-scripts.md`.

## Test plan

Invariants the tests must protect:

- **No interleaved commits** — two concurrent `scripts/orianna-sign.sh` <!-- orianna: ok -- existing script --> invocations
  cannot produce a commit whose message belongs to one invocation and whose
  diff belongs to the other. Enforced by T1 (reject-second-sign) and T2
  (sign-then-promote serialisation).
- **Lock fast-fail, not wait** — the second holder prints a holder-pid
  diagnostic and exits non-zero within one second. Matches existing
  plan-promote behavior; prevents subagents hanging on contention.
- **Auto-derive is transparent** — explicit `STAGED_SCOPE=<path>` still wins;
  unset-case produces identical commit shape to the explicit case. Add a
  single assertion to the existing
  `scripts/__tests__/test-orianna-sign-staged-scope.sh` harness rather than
  a net-new file.
- **Lockfile lives under `.git/`** <!-- orianna: ok -- dir token, not a tracked path --> — never appears in `git status`,
  never tracked, survives a `scripts/safe-checkout.sh` <!-- orianna: ok -- existing script --> worktree switch without
  confusion. Asserted via `git check-ignore` or a post-run `git status` <!-- orianna: ok -- git subcommand, not a path -->
  cleanliness check in T2.

All tests are POSIX-portable bash (Rule 10) and run under the standard
pre-push hook / CI TDD gate (Rule 12). Each implementation task in §Tasks is
preceded on-branch by its matching xfail test per Rule 12.

## References

- `scripts/plan-promote.sh` — existing flock pattern, source for T3 extraction.
- `scripts/orianna-sign.sh` — target of T4, T5.
- `scripts/__tests__/test-orianna-sign-staged-scope.sh` — extend for T5 assertion.
- `plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md` — STAGED_SCOPE origin.
- `agents/evelynn/inbox/archive/2026-04/2026-04-22-bash-cwd-wedge-feedback.md` — incident diagnosis.
- `agents/ekko/learnings/2026-04-22-promote-to-implemented-signature-invalidation.md` — recovery pattern.
- Rule 4 (plans direct to main), Rule 12 (xfail first), Rule 19 (Orianna gate on every transition).

## Test results

PR #22 merge commit: `94c65caf11c39cf1ca66db05506d42ee730de581`
Head SHA: `60aa6608c3c61d16e93fc8b10a04b63854d522d4`

All CI checks passed:

| Check | Workflow | Conclusion | Run URL |
|-------|----------|------------|---------|
| xfail-first check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24771041266/job/72477259255 |
| xfail-first check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24771040052/job/72477255049 |
| regression-test check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24771041266/job/72477259187 |
| regression-test check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24771040052/job/72477255003 |
