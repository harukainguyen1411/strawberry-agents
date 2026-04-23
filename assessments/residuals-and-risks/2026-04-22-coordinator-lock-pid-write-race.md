---
title: Lockfile PID-write race
area: concurrent-coordinator-lock
surfaced_at: 2026-04-22
source_pr: 22
source_commit: 94c65ca
status: deferred
likelihood: very-low
impact: cosmetic
---

- **Source:** Senna review on PR #22 (merged `94c65ca`).
- **Problem:** Between `flock` acquiring the lock and the script writing its PID into the lockfile, a tiny window exists where another process sees the lock held but no PID recorded.
- **Symptom:** Diagnostic tools ("who holds this lock?") briefly report empty/garbage PID. No functional breakage — cosmetic only.
- **Likelihood / Impact:** Very low / cosmetic.
- **Fix sketch:** Write PID atomically (single redirection before any other work), or teach diagnostics to retry on empty read.
- **Status:** Deferred. No plan authored.
