# Lissandra

## Role
- PR Reviewer (surface: logic, security, edge cases)

## Sessions (recent)
- s8: PR #29 (GH_TOKEN scoping) approved. PR #30 (API key isolation) 1 blocker fixed, approved.
- s9: PR #31 (team-plan-migration) approved first-pass.
- s10: PR #32 (heartbeat fix) 1 blocker awaiting fix. PR #34 (restart safeguards) approved. PR #54 myapps (kanban board) 1 blocker awaiting fix.
- s11: PR #61 (CLAUDE.md 4-tier restructure) — 2 blockers found, changes requested.
- s12: PR #61 re-review — 2 blockers fixed (FIXED), 3 findings still open (MEDIUM+2 LOW), comment posted.
- Total: 21 PRs reviewed across 12 sessions (s1–s12, 2026-04-03 to 2026-04-09).

## Review History (last 10)
- PR #25: No-op window-existence detection, inconsistent exit-wait, silent exception. All fixed. Author: Bard.
- PR #29: GH_TOKEN shell scoping (VAR=$(cmd) cmd2 bug). Clean. Author: Katarina.
- PR #30: Per-agent ANTHROPIC_API_KEY injection. Blocker: no json.JSONDecodeError handling. Fixed. Author: Katarina.
- PR #31: Team plan migration — removed API key injection from launch_agent entirely. Clean. Author: Katarina.
- PR #32: Heartbeat fix (touch_heartbeat helper + 3 call sites). Blocker: speak_in_turn passes sender raw while message_agent normalizes with .lower().strip() — inconsistent. Author: Katarina.
- PR #34: Restart safeguards — sender auto-exclude on restart_agents, end_all_sessions→shutdown_all_agents with confirm gate. Clean. Author: Katarina.
- PR #54 (myapps): Kanban board view. Blocker: onSnapshot listener killed on view switch because BoardView conditionally skips load(). Author: Ornn.
- PR #61: CLAUDE.md 4-tier restructure. Blockers: (1) #rule-never-end-after-task anchor in SONNET_REF dead; (2) #rule-plans-direct-to-main duplicate anchor. Author: Katarina.
- PR #61 re-review: Both blockers fixed. Still open: Tier 2 pointer lacks section heading (MEDIUM); evelynn missing from OPUS_AGENTS without comment (LOW); startup item 7 self-referential (LOW, partially addressed). Comment posted 2026-04-09.

## Recurring patterns
- `--dangerously-skip-permissions` / unrestricted tool access keeps appearing. Flag proactively in any PR involving Claude CLI invocation.
- Glob-count-based ID generation is a recurring anti-pattern (PRs #19, #22). Always flag.
- Silent `except Exception: pass` blocks are common in this codebase — watch for cases where failures should be logged.
- Firebase Admin SDK bypasses Firestore security rules — check client-side Vue app rules cover new fields.
- Bash globs without nullglob or `[ -f ]` guard fail on empty directories in Git Bash on Windows.

## Protocol
- After posting a PR review, always message Evelynn with the PR number and verdict (approved/changes requested).

## Known Blockers
- Cannot request-changes on own repo PRs via gh CLI — post as comment instead.
