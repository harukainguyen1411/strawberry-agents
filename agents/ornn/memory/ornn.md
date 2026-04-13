# Ornn

## Role
- Fullstack Engineer — New Features

## Sessions
- 2026-04-03 S1: Tasklist app review + migration to myapps Vue/Firebase platform. PR #53.
- 2026-04-03 S2: Discord glue for contributor pipeline (notifications, approval buttons, merge tracking).
- 2026-04-04 S1: Shared task board — Firebase MCP tools + Vue app integration. PR #21.
- 2026-04-05 S3: Kanban board view (BoardView.vue, BoardCard.vue) — PR #54, halted mid-build for plan.
- 2026-04-05 S4: B3 completion — onSnapshot, indexes, e2e tests, listener lifecycle fix. PR #54 updated.
- 2026-04-12 S1 (subagent): CI fix — set 7 VITE_FIREBASE_* secrets on Duongntd/strawberry, deploy verified green.
- 2026-04-13 S1 (subagent): Firebase Hosting caching fix — deployed to both myapps-b31ea and darkstrawberry-landing sites. Key learnings: **/*.html does not match SPA routes like /; use ** catch-all for no-cache and let JS/CSS rules override with immutable. darkstrawberry.com is a separate hosting site (darkstrawberry-landing) with its own apps/landing/firebase.json. Fixed missing packageManager in package.json (turbo was broken). No GitHub remote.

## Context
- myapps repo: github.com/Duongntd/myapps — Vue 3 + Tailwind + Firebase (Auth + Firestore). Hosted on Firebase Hosting.
- App pattern: each app lives under src/views/<AppName>/ with layout + child routes, Pinia store, i18n support.
- Existing apps: Read Tracker, Portfolio Tracker, Task List (PR #53, merged), Board View (PR #54, open).
- Pre-commit hooks: lint-staged (eslint) + typecheck (vue-tsc) + test (vitest). All must pass.
- Clone to /tmp for work — repo is not in the strawberry workspace.

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
- Never commit to main directly when on a feature branch. Use `git worktree` for isolation.
- Firestore composite index required for queries with inequality + equality on different fields.
- Firebase Admin SDK task tools: validate status/priority/date before write; call _assert_doc_exists before update/delete.
- Firestore listener lifecycle: own load()/cleanup() in the layout component that wraps router-view, NOT in child views. Child views unmount on navigation; the layout persists. **Why:** Dashboard.onUnmounted killed listener before Board could use it — Board's guard skipped re-subscribe and showed stale data.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.