---
title: PID-wrap / stale-lock false positive
area: concurrent-coordinator-lock
surfaced_at: 2026-04-22
source_pr: 22
source_commit: 94c65ca
status: deferred
likelihood: low
impact: high-friction
---

- **Source:** Senna review on PR #22.
- **Problem:** If a coordinator crashes without releasing the lock and the OS later recycles that PID to an unrelated live process, the stale-lock check sees a "live" PID and refuses to break the lock.
- **Symptom:** New coordinator can't start until someone manually removes the lockfile. Requires crash + long uptime + PID exhaustion to hit.
- **Likelihood / Impact:** Low / high-friction when it hits (blocks coordinator start).
- **Fix sketch:** Record start-time (or boot ID) alongside PID; stale-check compares both so a recycled PID is detected.
- **Status:** Deferred. No plan authored.
