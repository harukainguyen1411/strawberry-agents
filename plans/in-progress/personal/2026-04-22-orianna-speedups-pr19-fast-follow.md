---
status: in-progress
concern: personal
owner: karma
created: 2026-04-22
complexity: quick
orianna_gate_version: 2
tests_required: true
architecture_impact: none
tags: [orianna-gate, hooks, scripts, fast-follow, senna-review]
related:
  - plans/implemented/personal/2026-04-21-orianna-gate-speedups.md
  - agents/senna/learnings/2026-04-21-pr17-staged-scope-guard-rereview.md
orianna_signature_approved: "sha256:859fa43042b17dc127b5ff0cb5a4363abd14c06c728ff27a171328ae6577cbd4:2026-04-22T13:45:26Z"
orianna_signature_in_progress: "sha256:859fa43042b17dc127b5ff0cb5a4363abd14c06c728ff27a171328ae6577cbd4:2026-04-22T13:46:20Z"
orianna_signature_implemented: "sha256:859fa43042b17dc127b5ff0cb5a4363abd14c06c728ff27a171328ae6577cbd4:2026-04-22T13:47:36Z"
---

# Orianna speedups PR #19 fast-follow — Senna review hardenings

## 1. Context

PR #19 (merged at `98d310c`) shipped the orianna-gate-speedups work. Senna's re-review was an advisory LGTM: merge-clean, but she flagged three important hardenings and three lower-priority nits as fast-follow. This plan addresses all six in one quick-lane pass before the noise compounds.

The three important findings are behavioral/correctness issues:
- F1: interactive stderr suppression in the Orianna signature-guard hook;
- F2: pre-fix mutations left in the working tree when claude fact-check returns block-findings (Rule 1 violation — uncommitted tree changes on main);
- F3: `grep -c || echo 0` emits `"0\n0"` on miss (macOS zsh confirmed), breaking downstream arithmetic silently.

F4 (predictable `/tmp` path), F5 (reason-form regex rejects leading-dash reasons), and F6 (stale comment referencing a renamed hook) are cheap one-liners and folded in here rather than spun into a separate plan.

F2 is the meaty one and gets xfail-first treatment — it is a contract change (snapshot/restore around claude invocation). F1, F3, F4, F5, F6 are surgical enough to land impl-direct under the trust-me-it's-trivial clause of the TDD rule; each is verified by a targeted manual check in the test plan.

## 2. Decision

Patch the three hooks/scripts in place. No API or interface changes. No new files except one xfail test. No schema or invariant changes.

## Tasks

### T1. Add xfail test for pre-fix snapshot/restore contract (F2)
- kind: test
- estimate_minutes: 20
- files: `scripts/hooks/tests/test-orianna-sign-prefix-restore.sh` (new) <!-- orianna: ok -- new file, created by this plan -->
- detail: Bash test that stages a plan with pre-fix-eligible content, stubs `claude` to emit a report with `block_findings: 1`, runs `scripts/orianna-sign.sh`, and asserts the plan file on disk is byte-identical to its pre-sign state. Reference this plan and T2 in the test header. Test must fail on current `main` (xfail) and pass after T2. Wire into `scripts/hooks/tests/` runner if one exists; otherwise leave as standalone invoked via `test-hooks.sh`. <!-- orianna: ok -- directory token, runner exists as scripts/hooks/tests/ dir -->
- DoD: test file committed, runs red on `main` with a clear diff showing plan mutation, plan cited in xfail comment.

### T2. Snapshot-and-restore plan around claude fact-check in scripts/orianna-sign.sh (F2)
- kind: impl
- estimate_minutes: 25
- files: `scripts/orianna-sign.sh`
- detail: Before invoking orianna-pre-fix (or any pre-claude plan mutation), copy the plan to a tempfile via `mktemp`. If claude returns block-findings or exit 1, restore the snapshot over the plan path before exit 1. On clean-path success, discard the snapshot. Keep the control flow linear; do not introduce traps that fire on normal exit. Preserve existing stderr messaging.
- DoD: T1 flips green; manual re-run of the full sign flow on a clean plan still produces a valid signature commit; sign flow on a block-findings plan exits 1 and leaves the plan unchanged — `git status` is clean for the plan file.

### T3. TTY-guard the stderr log-tap in signature-guard hook (F1)
- kind: impl
- estimate_minutes: 5
- files: `scripts/hooks/pre-commit-orianna-signature-guard.sh`
- detail: Replace the unconditional `exec 2>>"$GIT_DIR/orianna-sig-guard.log"` with `if [ ! -t 2 ]; then exec 2>>"$GIT_DIR/orianna-sig-guard.log"; fi`. Preserves capture under the test harness (non-TTY stderr) while restoring interactive visibility. Note: current HEAD of the file (as of a18e20b) does not contain the exec redirect — confirm via `grep exec` and apply only if present; otherwise add the guard at the relevant log sink added post-merge if one exists, or mark T3 as no-op with a note in the commit message.
- DoD: grep confirms the guarded form or a documented no-op; running `git commit` as Orianna in an interactive shell writes guard stderr to the terminal; the existing test suite `scripts/hooks/test-pre-commit-orianna-signature.sh` still passes.

### T4. Fix `grep -c || echo 0` double-zero bug (F3)
- kind: impl
- estimate_minutes: 10
- files: `scripts/hooks/pre-commit-orianna-signature-guard.sh`
- detail: Audit every `$(grep -c PATTERN ... || echo 0)` in the file (at minimum the `NUM_STAGED` assignment around line 39 and the `ADDED_SIG_LINES` assignment around line 63). Replace with the pattern `$(grep -c PATTERN ... || true)` and a follow-up normalization `VAR=${VAR:-0}`, or equivalently `VAR=$(grep -c PATTERN ... 2>/dev/null); VAR=${VAR:-0}`. Verify on macOS zsh that a zero-match yields single `0`, not `0\n0`. Downstream `[ "$NUM_STAGED" -ne 1 ]` arithmetic must remain correct.
- DoD: `printf '' | grep -c x || true` sanity check returns empty; the assignment form in the hook returns `0` (single token) under `set -eu` with no matches; existing hook tests still green.

### F4. `mktemp` the body-hash-guard failure log
- kind: impl
- estimate_minutes: 5
- files: `scripts/hooks/pre-commit-orianna-body-hash-guard.sh` (locate via grep if path differs post-merge) <!-- orianna: ok -- prospective path, may be inlined post-merge -->
- detail: Replace `/tmp/body-hash-guard-failures-$$.txt` with `$(mktemp -t body-hash-guard-failures.XXXXXX)`. Keep the same log contents and cleanup semantics. If the file no longer exists (hook may have been inlined), mark F4 no-op in the commit message.
- DoD: grep for `body-hash-guard-failures` shows only the `mktemp` form or confirmed absence; hook behavior unchanged on a normal commit.

### F5. Widen T11.c reason-form regex to allow leading dash
- kind: impl
- estimate_minutes: 5
- files: `scripts/hooks/pre-commit-zz-plan-structure.sh`
- detail: The reason-form regex for `<!-- orianna: ok -- <reason> -->` uses `[^-]` at reason start, rejecting reasons that legitimately begin with `-` (e.g. `-- new file, created by this plan`). Relax to allow any non-whitespace first char while still requiring the leading `-- ` separator. Do not relax the closing `-->` sentinel.
- DoD: an inline suppressor with a leading-dash reason passes the hook; an empty reason still fails.

### F6. Update install-hooks.sh comment to reference zz-plan-structure filename
- kind: impl
- estimate_minutes: 3
- files: `scripts/install-hooks.sh`
- detail: The install script contains a comment referencing `pre-commit-t-plan-structure.sh` (retired filename). <!-- orianna: ok -- retired path, no longer exists --> Rename the reference to `scripts/hooks/pre-commit-zz-plan-structure.sh` to match current filename. Comment-only change; no behavior delta.
- DoD: `grep t-plan-structure scripts/install-hooks.sh` returns no matches (excluding any historical log file).

## Test plan

Invariants protected:
- **F2 contract:** a failed claude fact-check MUST NOT leave plan mutations in the working tree (Rule 1 — no uncommitted state after a refused sign).
- **F1 UX:** interactive commits surface guard errors; non-interactive (test harness) runs still log to the sink.
- **F3 arithmetic:** `NUM_STAGED` and `ADDED_SIG_LINES` produce single-token integers under `set -eu` on macOS and Linux.

Tests:
- T1 (new, xfail→green in T2): `scripts/hooks/tests/test-orianna-sign-prefix-restore.sh` <!-- orianna: ok -- new file, created by T1 --> — stubs claude block-findings, asserts plan byte-equality post-sign-failure.
- Regression: existing `scripts/hooks/test-pre-commit-orianna-signature.sh` must continue to pass after T3 and T4.
- Manual smoke (F1): run an interactive `git commit` as Orianna identity on a malformed signing commit; confirm error text appears on terminal AND in `$GIT_DIR/orianna-sig-guard.log`. <!-- orianna: ok -- GIT_DIR is a shell variable, not a repo path -->
- Manual smoke (F3): stage zero plan files and invoke the hook directly; confirm `NUM_STAGED=0` (single token), guard rejects cleanly with the expected error line.
- F4, F5, F6 are covered by their per-task DoD grep checks — no dedicated test.

No schema or migration work. No external integration touched.

## Open questions

None. F4/F5/F6 ruled in-scope per the brief ("if cheap"); all three are one-liners adjacent to the F1/F2/F3 hunks, so folding them in keeps the sign cycle count low.

## Architecture impact

No architecture/ files modified. Changes are surgical patches to scripts/orianna-sign.sh, scripts/hooks/pre-commit-orianna-signature-guard.sh, scripts/hooks/pre-commit-zz-plan-structure.sh, scripts/hooks/pre-commit-orianna-body-hash-guard.sh, and scripts/install-hooks.sh. No new architectural patterns introduced.

## Test results

- PR #23 merged at 36afa9a (final, incorporating PR #19 + #27 fast-follow): https://github.com/harukainguyen1411/strawberry-agents/pull/23
- All required checks green at merge.

## References

- Senna review: `agents/senna/learnings/2026-04-21-pr17-staged-scope-guard-rereview.md`
- Parent plan: `plans/implemented/personal/2026-04-21-orianna-gate-speedups.md` <!-- orianna: ok -- plan promoted to implemented -->
- PR #19 merge commit: `98d310c`
