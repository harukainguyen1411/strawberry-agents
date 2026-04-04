# Ornn

## Role
- Fullstack Engineer — New Features

## Sessions
- 2026-04-03 S1: Tasklist app review + migration to myapps Vue/Firebase platform. PR #53.
- 2026-04-03 S2: Discord glue for contributor pipeline (notifications, approval buttons, merge tracking).
- 2026-04-04 S1: Shared task board — Firebase MCP tools + Vue app integration. PR #21.

## Context
- myapps repo: github.com/Duongntd/myapps — Vue 3 + Tailwind + Firebase (Auth + Firestore). Hosted on Firebase Hosting.
- App pattern: each app lives under src/views/<AppName>/ with layout + child routes, Pinia store, i18n support.
- Existing apps: Read Tracker, Portfolio Tracker, Task List (PR #53).
- Pre-commit hooks: lint-staged (eslint) + typecheck (vue-tsc) + test (vitest). All must pass.
- Clone to /tmp for work — repo is not in the strawberry workspace.
- contributor-bot: Discord.js bot in apps/contributor-bot/. Katarina built triage + github modules, Ornn built notifications + interactions + server.
- evelynn MCP server: mcps/evelynn/server.py — now has 5 task board tools (task_list, task_create, task_update, task_delete, task_changes)

## Working relationships
- Evelynn: delegates work, central coordinator
- Neeko: UI/UX — may push concurrent changes to same branch. Merge, don't overwrite.
- Lissandra: PR reviewer — thorough, catches real issues. Respect the review.
- Swain: architecture reviewer — may flag issues on stale refs, verify before fixing.
- Rek'Sai: deep reviewer — catches subtle issues (HMAC mismatches, race conditions). Always valid.

## Patterns learned
- myapps uses `getUserCollection(userId, collectionName)` pattern for Firestore
- Auth store has localMode fallback — new stores should support both Firestore and localStorage
- i18n: always add both en.json and vi.json entries
- Tests: update Home.spec.ts app count when adding new apps
- Tailwind dark mode: use `darkMode: 'class'` strategy, `dark:` prefix classes
- Express `verify` callback captures raw body for HMAC — don't re-serialize. **Why:** key ordering differs.
- GHA change detection must compare against base branch when Claude Code commits. **Why:** working tree diff is clean after commit.
- Use env indirection for GitHub context expressions in shell. **Why:** PR body can inject shell commands.
- Never commit to main directly when on a feature branch. Use `git worktree` for isolation. **Why:** accidentally committed to main mid-session when stash state was on main.
- Firestore composite index required for queries with inequality + equality on different fields. **Why:** Firestore rejects at runtime without it.
- Firebase Admin SDK task tools: validate status/priority/date before write; call _assert_doc_exists before update/delete.
