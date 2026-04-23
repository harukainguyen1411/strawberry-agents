---
title: $BASHPID test coverage gap
area: concurrent-coordinator-lock
surfaced_at: 2026-04-22
source_pr: 22
source_commit: 94c65ca
status: deferred
likelihood: low
impact: moderate
---

- **Source:** Senna review on PR #22.
- **Problem:** Existing tests don't exercise the subshell PID path. `$$` returns the parent shell PID; `$BASHPID` returns the actual subshell. If lock code uses the wrong one inside a pipeline or `( ... )` subshell, two coordinators in the same parent shell could collide silently.
- **Symptom:** Today, none — tests pass. Latent risk if lock code is ever refactored into a pipeline/subshell context.
- **Likelihood / Impact:** Low / moderate if triggered.
- **Fix sketch:** Add tests that deliberately acquire the lock inside `( ... )` subshells and assert the correct PID is recorded.
- **Status:** Deferred. No plan authored.
