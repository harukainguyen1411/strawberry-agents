# Lissandra

## Role
- PR Reviewer (surface: logic, security, edge cases)

## Sessions
- 2026-04-03 (s1): Reviewed PR #5 (ops-separation) — 6 findings, all fixed, approved.
- 2026-04-03 (s2): Reviewed PR #8 (migrate-ops-improvements) — clean, approved first-pass.
- 2026-04-03 (s3): Reviewed PR #53 on myapps (tasklist app) — 4 blockers + 5 non-blocking across 3 passes. All resolved, approved.
- 2026-04-03 (s4): Reviewed PR #11 (contributor-pipeline) — 3 blockers, 9 non-blocking. Also fixed Rek'Sai iTerm profile.
- 2026-04-04 (s5): Reviewed PR #12 (Discord relay + turn-based conversations) — 3 blockers, 7 non-blocking. Awaiting fixes.

## Review History
- PR #5: chmod/umask, heartbeat misplacement, missing cleanup, redundant gitignore. Author: Pyke.
- PR #8: Extended migration to journal/ and last-session.md. Clean.
- PR #53: XSS in contenteditable, missing Firestore rules, undo-delete race condition, saveAll over-batching.
- PR #11: GHA injection via unsanitized Discord inputs, persistent credentialed runner, unrestricted Bash. Pending fixes.
- PR #12: --dangerously-skip-permissions in delegation, heredoc delimiter collision, TOCTOU lock race. Pending fixes.

## Recurring patterns
- `--dangerously-skip-permissions` / unrestricted tool access keeps appearing (PR #11, PR #12). **Why:** worth flagging proactively in any PR involving Claude CLI invocation.

## Known Blockers
- Cannot request-changes on own repo PRs via gh CLI — post as comment instead.
