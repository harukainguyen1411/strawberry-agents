# MyApps Current State Snapshot — 2026-04-08

## 1. Repo Location and Remote

- **Disk path:** `/c/Users/AD/Duong/strawberry/apps/myapps`
- **Remote URL:** https://github.com/Duongntd/strawberry
- **Current branch:** main
- **Default branch:** main
- **Context:** MyApps is a monorepo app within the larger Strawberry monorepo (Duong's agent system). It is tracked at `apps/myapps/` within the Strawberry repo, not as a separate repo.
- **Firebase project ID:** `myapps-b31ea` (in `.firebaserc`)

---

## 2. What the App Does

MyApps is a personal multi-app platform built with Vue 3 and Firebase, hosting three independent productivity applications under one roof. The platform provides Google authentication, dual-mode operation (Firestore + localStorage), and a responsive UI for daily use.

**Three apps currently included:**
- **Read Tracker** (fully built): Log reading sessions, track books, set daily/weekly/monthly/yearly reading goals, visualize trends with line/bar charts, maintain streaks, and manage book status (reading/completed/want to read).
- **Portfolio Tracker** (partially built): Track stock holdings, log buy/sell transactions, fetch current stock prices, set account-level settings.
- **Task List** (partially built, reviewed in PR #53): Weekly drag-and-drop task board with day columns, status tracking, priority levels, undo support, and real-time Firestore sync (in progress).

The platform is designed for Duong's personal use and Evelynn's task coordination (shared task list via Firebase).

---

## 3. Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Vue 3 (Composition API) + TypeScript |
| **State Management** | Pinia |
| **Build Tool** | Vite 5.2.0 |
| **Styling** | Tailwind CSS 3.4.1 + PostCSS |
| **Charts** | Chart.js 4.4.1 + vue-chartjs 5.3.0 |
| **Backend** | Firebase v10.11.1 (Auth, Firestore, Hosting) |
| **Router** | Vue Router 4.3.0 |
| **i18n** | vue-i18n 9.14.5 |
| **Testing** | Vitest 4.0.18 (unit), Playwright 1.58.0 (E2E) |
| **Linting** | ESLint 9.39.2 + @vue/eslint-config |
| **Package Manager** | npm (lock file present) |
| **Bundling** | Vite with code splitting: vue-vendor, firebase-vendor, chart-vendor |

---

## 4. Deployment Flow Today

### Hosting
- **Host:** Firebase Hosting (myapps-b31ea.web.app)
- **Build output:** `dist/` directory (Vite SPA output)
- **Entry point:** index.html with SPA rewrites (all routes to /index.html)

### CI/CD
**Two GitHub Actions workflows:**

1. **ci.yml** (on push to main / PR to main):
   - Lint (ESLint)
   - Typecheck (vue-tsc)
   - Unit tests (vitest)
   - Build with fallback Firebase secrets
   - E2E tests (Playwright, chromium)

2. **deploy-release.yml** (on GitHub Release):
   - Parses release tag/notes
   - Extracts Firebase config from FIREBASE_CONFIG secret (JSON)
   - Builds with versioned env vars
   - Deploys to Firebase Hosting via service account

### Manual Deployment
- `npm run build` then `npm run firebase deploy --only hosting`
- Requires local Firebase login + `.env` with real credentials

### Environment Variables
- All Firebase config injected at build time via `VITE_*` prefixed variables
- In GitHub Actions: parsed from `FIREBASE_CONFIG` JSON secret or fallback to placeholder
- Locally: read from `.env` file (template: `.env.example`)

### Security
- Security headers: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection
- Aggressive caching for images/JS/CSS (1 year)
- HTML cache: default (no-cache)

---

## 5. Test Infrastructure Today

### Unit Tests
- **Framework:** Vitest 4.0.18
- **Tests:** `src/views/Home.spec.ts`, `src/views/PortfolioTracker/Dashboard.spec.ts`, `src/stores/portfolio.spec.ts`
- **Coverage:** v8, reports in text/json/html
- **Commands:** `npm run test:run` (CI), `npm run test` (watch), `npm run test:coverage`

### E2E Tests
- **Framework:** Playwright 1.58.0 (Chromium in CI)
- **Tests found:**
  - `e2e/auth-local-mode.spec.ts`
  - `e2e/forms-crud.spec.ts`
  - `e2e/home.spec.ts`
  - `e2e/navigation.spec.ts`
  - `e2e/portfolio-tracker.spec.ts`
  - `e2e/read-tracker.spec.ts`
  - MISSING: `e2e/task-list.spec.ts`
- **Strategy:** Runs against production build (vite preview), captures on-failure screenshots/video
- **Commands:** `npm run test:e2e` (watch), `npm run test:e2e:ci` (chromium)

### Linting & Types
- ESLint 9.39.2 + Vue plugin
- vue-tsc typecheck
- Husky pre-commit hook for lint-staged

---

## 6. Recent Activity and Open PRs

### MyApps-Specific Commits
- 258152d: fix PR #21 — input validation, doc checks, composite index
- b0d2df4: feat shared task board — Firebase MCP tools + Vue app
- 3859739: docs myapps README as triage context
- 8ef56cc: feat Task List app with calendar, drag-drop, dark mode

### Open Branches
- `swain/b3-task-list-plan` (approved plan, awaiting implementation)
- `feature/commit-ratio-tracker`
- `bard/heartbeat-fix`

### Critical Blocker
**PR #54 (from Evelynn memory note):** MyApps task list — reviewed, ready to merge. **Needs Firestore index deploy.**

### Approved B3 Plan (2026-04-05-myapps-task-list.md)
- Real-time Firestore listener (onSnapshot) — NOT YET DONE
- Firestore index for `_deleted + createdAt` — NOT YET DEPLOYED
- E2E test for task list — NOT YET CREATED
- Owner: Katarina/Ornn; Reviewer: Lissandra

---

## 7. Known Pain Points

### From Evelynn Memory
- PR #54 blocked: Firestore index deploy needed
- Real-time sync incomplete: src/stores/taskList.ts still uses getDocs (one-time fetch) instead of onSnapshot
- Task list changes from Evelynn don't appear in Duong's browser without manual refresh

### App-Level Gaps
- **Read Tracker:** No timers, no reminders, no cover images, no export
- **Portfolio Tracker:** No P/L charts, no dividends, no multi-currency
- **Task List:** No category UI, notes read-only, category field schema-ready

### Infrastructure
- No staging environment (only prod)
- Firebase free tier limits (50K reads/day, 20K writes/day) not monitoring alert
- No Firestore schema/security audit documented
- No incident runbook
- Deploy-only staging manual (Duong runs `firebase deploy` locally)

---

## 8. Questions Requiring Human Confirmation

1. **Firestore index deployment:** Who has CLI access? Should this be automated in GitHub Actions or stay manual?
2. **Real-time sync:** Is onSnapshot intended? Should cleanup wire to component unmount or store lifecycle?
3. **SLA:** What's acceptable latency for Evelynn→Duong task updates?
4. **Secrets:** Which account owns FIREBASE_CONFIG and FIREBASE_SERVICE_ACCOUNT secrets? Rotation schedule?
5. **Next app:** Portfolio Tracker or new feature after Task List?
6. **Testing:** Should E2E run against staging Firestore or mock?
7. **Local dev:** Emulator Suite or live Firestore?
8. **Performance:** Any profiling done on Firestore queries? Are code-split chunk sizes on target?

---

## Summary for Planners

**Repo:** MyApps is Vue 3 + Firebase in Strawberry monorepo (`apps/myapps/`), not standalone.

**Current:** Three apps (Read Tracker ✓, Portfolio ~50%, Task List ~80%), shared auth/Firestore.

**Blocker:** Task List real-time sync not implemented (getDocs → onSnapshot needed) + Firestore index undeployed.

**Tech:** Vue 3, Vite, Pinia, Firebase, Tailwind, Playwright E2E, Vitest unit tests.

**Deployment:** Firebase Hosting, automated CI (ESLint/typecheck/build/E2E), manual index deploy.

**Next:** Implement real-time listener, add Firestore index, write task-list E2E test, merge PR #54.
