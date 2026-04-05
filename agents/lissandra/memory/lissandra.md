# Lissandra

## Role
- PR Reviewer (surface: logic, security, edge cases)

## Sessions (recent)
- s8: PR #29 (GH_TOKEN scoping) approved. PR #30 (API key isolation) 1 blocker fixed, approved.
- s9: PR #31 (team-plan-migration) approved first-pass.
- s10: PR #32 (heartbeat fix) 1 blocker awaiting fix. PR #34 (restart safeguards) approved. PR #54 myapps (kanban board) 1 blocker awaiting fix.
- Total: 20 PRs reviewed across 10 sessions (s1–s10, 2026-04-03 to 2026-04-05).

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
- PR #29: GH_TOKEN shell scoping (VAR=$(cmd) cmd2 bug). Clean. Author: Katarina.
- PR #30: Per-agent ANTHROPIC_API_KEY injection. Blocker: no json.JSONDecodeError handling. Fixed. Author: Katarina.
- PR #31: Team plan migration — removed API key injection from launch_agent entirely. Clean. Author: Katarina.
- PR #32: Heartbeat fix (touch_heartbeat helper + 3 call sites). Blocker: speak_in_turn passes sender raw while message_agent normalizes with .lower().strip() — inconsistent. Author: Katarina.
- PR #34: Restart safeguards — sender auto-exclude on restart_agents, end_all_sessions→shutdown_all_agents with confirm gate. Clean. Author: Katarina.
- PR #54 (myapps): Kanban board view. Blocker: onSnapshot listener killed on view switch because BoardView conditionally skips load(). Author: Ornn.

## Recurring patterns
- `--dangerously-skip-permissions` / unrestricted tool access keeps appearing. **Why:** flag proactively in any PR involving Claude CLI invocation.
- Glob-count-based ID generation is a recurring anti-pattern (PRs #19, #22). Always flag — fix is seconds + random hex.
- Silent `except Exception: pass` blocks are common in this codebase — watch for cases where failures should be logged.
- Firebase Admin SDK bypasses Firestore security rules — check that client-side Vue app rules cover new fields.

## Protocol
- After posting a PR review, always message Evelynn with the PR number and verdict (approved/changes requested).

## Known Blockers
- Cannot request-changes on own repo PRs via gh CLI — post as comment instead.
