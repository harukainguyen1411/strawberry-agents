---
plan: plans/proposed/2026-04-19-apps-restructure-darkstrawberry-layout.md
checked_at: 2026-04-19T14:30:00Z
auditor: orianna
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 4
---

## Block findings

None.

## Warn findings

None.

## Info findings

<!-- Forward-looking target paths (apps/darkstrawberry-apps/**, apps/workers/**,
apps/webhooks/**, apps/discord/**, apps/dashboards/**, apps/contributor/**,
darkstrawberry-apps-pr-preview.yml, etc.) are not flagged: per claim-contract §2
these are clearly marked speculative/future-state inside Phase N sections,
"Target:" table columns, and `→` arrows in a restructure ADR. Not present-tense
claims. -->

1. **Claim:** `apps/portal` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/apps/portal` | **Result:** not found — plan correctly asserts this path is stale and removes it in Phase 0; verified-true-negative | **Severity:** info

2. **Claim:** `tsconfig.base.json` | **Anchor:** `test -e ~/Documents/Personal/strawberry-app/tsconfig.base.json` | **Result:** not found — plan correctly asserts "does not exist" (Q7 resolution); verified-true-negative | **Severity:** info

3. **Claim:** inventory paths under `apps/` (myapps, myapps/portfolio-tracker, myapps/read-tracker, myapps/task-list, myapps/src/views/{bee,PortfolioTracker,ReadTracker,TaskList}, yourApps/bee, private-apps/bee-worker, coder-worker, contributor-bot, discord-relay, deploy-webhook, landing, platform, shared, myapps/firebase.json, myapps/functions, myapps/firestore.rules, myapps/storage.rules, myapps/e2e, landing/firebase.json) | **Anchor:** `test -e` against strawberry-app checkout | **Result:** all present | **Severity:** info

4. **Claim:** dashboards + config anchors (`dashboards/usage-dashboard`, `dashboards/server`, `dashboards/test-dashboard`, `dashboards/dashboard`, `dashboards/shared`, `packages/vitest-reporter-tests-dashboard`, all `.github/workflows/*.yml` referenced in §2c, `release-please-config.json`, `.release-please-manifest.json`, `ecosystem.config.js`, `turbo.json`, `package.json`, `.firebaserc`) and local `scripts/plan-promote.sh` | **Anchor:** `test -e` against applicable repo | **Result:** all present | **Severity:** info
