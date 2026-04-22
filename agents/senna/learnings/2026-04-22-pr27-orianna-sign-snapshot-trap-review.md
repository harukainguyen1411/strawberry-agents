# 2026-04-22 — PR #27 Orianna-sign snapshot trap coverage review

## Context
Fast-follow to PR #23 addressing the residual gap I flagged: snapshot/restore only fired on `block_count>0 || claude_exit==1`. PR #27 replaces single-path manual restore with a universal `trap` covering EXIT, SIGINT, SIGTERM. Branch `fix/orianna-sign-snapshot-trap-coverage`.

## Verdict
APPROVED. Trap ordering, signal re-raise, and success-path disarm all correct. All five focus areas cleared.

## Trace-through findings

1. **Trap restores before re-raise** — correct. `cp; rm; kill -SIG` in that order inside `_snapshot_restore_trap`.
2. **Success path** — L335 `rm -f "$_PLAN_SNAPSHOT"` before commit work, so EXIT trap sees no snapshot and no-ops.
3. **Signal re-raise** — uses `trap - SIG; kill -SIG $$` which produces correct exit codes (130/143) via default action.
4. **Snapshot-vs-trap-registration race** — no mutation happens in the ~24-line window between snapshot creation (L219) and trap arming (L243). Pre-fix is the first mutator and runs after trap arming.
5. **xfail tests fail pre-fix** — verified by tracing pre-fix script behavior against both tests' assertions.

## Residual issues flagged (non-blocking)

- **`cp ... 2>/dev/null || true`** swallows restore failures while still logging "plan restored". Recommended `if cp; then log-ok; else log-warn; fi` form.
- **Post-L335 `die()` paths** at L341/L368 run after the snapshot is discarded. Pre-fix mutations would persist on disk on these paths, but gate has already passed → mutations are "intentional"; pre-fix is idempotent on rerun. Defensible as-is but spec-strict reading would want a second post-success snapshot.
- **Test writes into real `plans/proposed/personal/`** — `_talon-test-*` prefix avoids collisions but ungitignored. Harmless.
- **Test 1 `trap cleanup_plan EXIT` overwrites earlier `trap "rm -rf $TMPDIR1" EXIT`** — TMPDIR1 never cleaned up. Harmless.

## Reusable technique
When a PR claims "universal signal trap," check four things:
1. Restore-before-reraise ordering (user's plan state must be right before signal propagates).
2. Success-path disarm (discard snapshot before clean exit so EXIT trap no-ops).
3. Re-raise via `trap - SIG; kill -SIG $$` for correct exit codes (not bare `exit 130`).
4. No mutation in the gap between resource creation and trap arming.

Also: check every `|| true` in an error-handling path — they frequently mask the very failures the handler exists to report.

## Lane hygiene
`scripts/reviewer-auth.sh --lane senna` confirmed `strawberry-reviewers-2`. APPROVED review posted.

## Review URL
https://github.com/harukainguyen1411/strawberry-agents/pull/27
