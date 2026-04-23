---
area: concurrent-coordinator-lock
source_pr: 22
source_commit: 94c65ca
surfaced_at: 2026-04-22
status: deferred
---

Risks surfaced during Senna's review of PR #22 (flock-based coordinator lock, merged `94c65ca`). Plan context: `plans/implemented/personal/2026-04-22-concurrent-coordinator-race-closeout.md`.

## I1 — Lockfile PID-write race

- **Source:** Senna review on PR #22 (merged `94c65ca`).
- **Problem:** Between `flock` acquiring the lock and the script writing its PID into the lockfile, a tiny window exists where another process sees the lock held but no PID recorded.
- **Symptom:** Diagnostic tools ("who holds this lock?") briefly report empty/garbage PID. No functional breakage — cosmetic only.
- **Likelihood / Impact:** Very low / cosmetic.
- **Fix sketch:** Write PID atomically (single redirection before any other work), or teach diagnostics to retry on empty read.
- **Status:** Deferred. No plan authored.

## I2 — PID-wrap / stale-lock false positive

- **Source:** Senna review on PR #22.
- **Problem:** If a coordinator crashes without releasing the lock and the OS later recycles that PID to an unrelated live process, the stale-lock check sees a "live" PID and refuses to break the lock.
- **Symptom:** New coordinator can't start until someone manually removes the lockfile. Requires crash + long uptime + PID exhaustion to hit.
- **Likelihood / Impact:** Low / high-friction when it hits (blocks coordinator start).
- **Fix sketch:** Record start-time (or boot ID) alongside PID; stale-check compares both so a recycled PID is detected.
- **Status:** Deferred. No plan authored.

## $BASHPID test coverage gap

- **Source:** Senna review on PR #22.
- **Problem:** Existing tests don't exercise the subshell PID path. `$$` returns the parent shell PID; `$BASHPID` returns the actual subshell. If lock code uses the wrong one inside a pipeline or `( ... )` subshell, two coordinators in the same parent shell could collide silently.
- **Symptom:** Today, none — tests pass. Latent risk if lock code is ever refactored into a pipeline/subshell context.
- **Likelihood / Impact:** Low / moderate if triggered.
- **Fix sketch:** Add tests that deliberately acquire the lock inside `( ... )` subshells and assert the correct PID is recorded.
- **Status:** Deferred. No plan authored.
