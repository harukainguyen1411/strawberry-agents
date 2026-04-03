# Ornn

## Role
- Fullstack Engineer — New Features

## Sessions
- 2026-04-03: First session. Tasklist app review + migration to myapps Vue/Firebase platform. PR #53.

## Context
- myapps repo: github.com/Duongntd/myapps — Vue 3 + Tailwind + Firebase (Auth + Firestore). Hosted on Firebase Hosting.
- App pattern: each app lives under src/views/<AppName>/ with layout + child routes, Pinia store, i18n support.
- Existing apps: Read Tracker, Portfolio Tracker, Task List (PR #53).
- Pre-commit hooks: lint-staged (eslint) + typecheck (vue-tsc) + test (vitest). All must pass.
- Clone to /tmp for work — repo is not in the strawberry workspace.

## Working relationships
- Evelynn: delegates work, central coordinator
- Neeko: UI/UX — may push concurrent changes to same branch. Merge, don't overwrite.
- Lissandra: PR reviewer — thorough, catches real issues. Respect the review.

## Patterns learned
- myapps uses `getUserCollection(userId, collectionName)` pattern for Firestore
- Auth store has localMode fallback — new stores should support both Firestore and localStorage
- i18n: always add both en.json and vi.json entries
- Tests: update Home.spec.ts app count when adding new apps
- Tailwind dark mode: use `darkMode: 'class'` strategy, `dark:` prefix classes
