# Lissandra

## Role
- PR Reviewer (surface: logic, security, edge cases)

## Sessions
- 2026-04-03 (s1): Reviewed PR #5 (ops-separation) — 6 findings, all fixed, approved.
- 2026-04-03 (s2): Reviewed PR #8 (migrate-ops-improvements) — clean, approved first-pass.
- 2026-04-03 (s3): Reviewed PR #53 on myapps (tasklist app) — 4 blockers + 5 non-blocking across 3 passes. All resolved, approved.
- 2026-04-03 (s4): Reviewed PR #11 (contributor-pipeline) — 3 blockers, 9 non-blocking. Also fixed Rek'Sai iTerm profile.
- 2026-04-04 (s5): Reviewed PR #12 (Discord relay + turn-based conversations) — 3 blockers, 7 non-blocking. Awaiting fixes.
- 2026-04-04 (s6): Reviewed PRs #15, #17, #18, #19, #20, #21, #22, #24 — all approved.
- 2026-04-04 (s7): Reviewed PR #25 (restart-detection-fix) — 1 blocker, 2 non-blocking. All fixed, approved pass 2.

## Review History
- PR #5: chmod/umask, heartbeat misplacement, missing cleanup, redundant gitignore. Author: Pyke.
- PR #8: Extended migration to journal/ and last-session.md. Clean.
- PR #53: XSS in contenteditable, missing Firestore rules, undo-delete race condition, saveAll over-batching.
- PR #11: GHA injection via unsanitized Discord inputs, persistent credentialed runner, unrestricted Bash.
- PR #12: --dangerously-skip-permissions in delegation, heredoc delimiter collision, TOCTOU lock race.
- PR #15: sender enforcement theater, stash pop silent failure, code duplication. All fixed.
- PR #17: find_agent_session break clarity, Claude CLI JSONL dependency, fixed-sleep race. All fixed.
- PR #18: Notification timing (before session alive). No blockers.
- PR #19: Minute-level filename collision (messages lost), no poll backoff. Fixed.
- PR #20: Context health monitoring. No blockers. Stale session_start risk noted.
- PR #21: Firebase task board — no input validation, missing composite index, no existence check. All fixed.
- PR #22: Task delegation — glob-count ID collision. Fixed.
- PR #24: restart_evelynn notification timing — poll loop added. Approved.
- PR #25: No-op window-existence detection, inconsistent exit-wait, silent exception. All fixed. Author: Bard.

## Recurring patterns
- `--dangerously-skip-permissions` / unrestricted tool access keeps appearing. **Why:** flag proactively in any PR involving Claude CLI invocation.
- Glob-count-based ID generation is a recurring anti-pattern (PRs #19, #22). Always flag — fix is seconds + random hex.
- Silent `except Exception: pass` blocks are common in this codebase — watch for cases where failures should be logged.
- Firebase Admin SDK bypasses Firestore security rules — check that client-side Vue app rules cover new fields.

## Known Blockers
- Cannot request-changes on own repo PRs via gh CLI — post as comment instead.
