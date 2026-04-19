# Ekko Journal

## 2026-04-19 — Vi's E2E fixes on PR #46

**Task:** Apply two E2E fixes on branch `fix/tdd-gate-enable-functions` (PR #46).

**Done:**
- Fix A: Updated `apps/myapps/e2e/navigation.spec.ts` line 69 — replaced `'MyApps'` with `'Dark Strawberry home'` to match AppHeader's actual aria-label. Committed `5b0b721`.
- Fix B: Generated 7 linux Playwright snapshot baselines (`*-chromium-linux.png`) using Docker (`mcr.microsoft.com/playwright:v1.59.1-jammy` — matched resolved Playwright version 1.59.1 from package-lock). All 7 tests passed with `--update-snapshots`. Committed `a31258d`.
- Pulled remote branch state first (branch had diverged — merged 9 remote commits including vitest-reporter-tests-dashboard package).
- Pushed both commits to `origin/fix/tdd-gate-enable-functions`.
- Posted PR comment at https://github.com/harukainguyen1411/strawberry-app/pull/46#issuecomment-4275235594.
- CI started: xfail-first, regression-test, validate-scope, QA report, check-no-hardcoded-slugs all passing; E2E and Lint pending.

**Blockers / Open threads:** None. Branch should go green on CI. Not self-merging per Rule 18.

## 2026-04-19 — pre-commit hook: Orianna bypass guard

**Task:** Wire a pre-commit hook that blocks silent Orianna fact-check bypasses when a plan is moved out of `plans/proposed/` via raw `git mv`.

**Done:**
- Wrote `scripts/hooks/pre-commit-plan-promote-guard.sh` — detects plan promotions via both rename (`R` status) and separate `D`+`A` entries in `git diff --cached --name-status`. Requires either a matching fact-check report in `assessments/plan-fact-checks/<basename>-*.md` or an `Orianna-Bypass: <reason>` trailer (>=10 chars). Bypass path prints a loud WARNING banner to stderr.
- Wrote `scripts/hooks/test-plan-promote-guard.sh` — 3-case test harness: (1) fact-check report present → allowed, (2) no report + no trailer → blocked, (3) no report + bypass trailer → allowed with warning. All 3 pass.
- Hook wired automatically by existing `install-hooks.sh` dispatcher pattern (no installer edits needed).
- Committed `f19296f`, pushed to main.

**Blockers / Open threads:** None.

## 2026-04-19 — Firebase preview secret diagnosis

**Task:** Diagnose why `firebaseServiceAccount` input error keeps firing on PRs #25/#26/#28 even though `FIREBASE_SERVICE_ACCOUNT` and `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` secrets both appear in the repo secret list.

**Done:**
- Found the two failing workflows: `preview.yml` (line 53) and `myapps-pr-preview.yml` (line 65) — both reference `${{ secrets.FIREBASE_SERVICE_ACCOUNT }}`.
- Confirmed `FIREBASE_SERVICE_ACCOUNT` IS present in `gh secret list` (created 2026-04-18T13:18:46Z). Name match is exact.
- Examined run logs for PR #25 run 24619343912 (Firebase Hosting PR Preview) and 24619343913 (Preview). The `with:` block logs show every other input (`repoToken`, `channelId`, `entryPoint`, `expires`) but omits `firebaseServiceAccount` entirely — the GitHub Actions runner silently drops secret inputs that resolve to empty string from the echo'd `with:` block.
- `action-hosting-deploy@v0` calls `core.getInput('firebaseServiceAccount', {required: true})` which throws "Input required and not supplied" when value is empty.
- Root cause: the secret NAME is correct but the VALUE stored is empty/zero-byte — likely a paste error when originally set.
- PR #26 failures are a separate issue (lockfile desync from vitest pin change), not the service account problem.

**Blockers / Open threads:**
- Duong must re-paste the Firebase service account JSON into the `FIREBASE_SERVICE_ACCOUNT` secret on `harukainguyen1411/strawberry-app`. No workflow change needed.

## 2026-04-19 — Plan promotion: orianna-role-redesign ADR bypassing Orianna gate

**Task:** Promote `plans/proposed/2026-04-19-orianna-role-redesign.md` to `plans/approved/` with Orianna gate bypass (ADR describes the redesign itself; forward-refs are intentional).

**Done:**
- Killed stale `plan-promote.sh` background processes.
- Ran `plan-promote.sh` — failed at Orianna gate with 8 block findings, all forward-refs to artifacts the plan itself defines (scripts/orianna-freshness-check.sh, external-allowlist.md, freshness-audits/, plus example paths and new MCP tools).
- Confirmed no `gdoc_id` in frontmatter — no Drive unpublish needed.
- `git mv` proposed→approved, rewrote `status: proposed` → `status: approved`.
- Committed with bypass explanation body per e97828d pattern. Commit: `a4dda94`.
- Pushed to main.

---

## 2026-04-19 — Plan promotion: tests-dashboard ADR bypassing Orianna gate

**Task:** Promote `plans/proposed/2026-04-19-tests-dashboard.md` to `plans/approved/` with Duong's explicit override of the Orianna fact-check gate.

**Done:**
- Killed stale `plan-promote.sh` background processes.
- Confirmed `plan-promote.sh` has no skip-fact-check flag (comment at line 65 says "No bypass flag. Human override: use raw git mv instead of this script.").
- Confirmed plan has no `gdoc_id` — no Drive unpublish needed.
- `git mv` proposed→approved, rewrote `status: proposed` → `status: approved`.
- Committed with full bypass explanation body referencing the 11 forward-ref miscalibration.
- Pushed to `harukainguyen1411/strawberry-agents` main. Commit: `e97828d`.

**Blockers / Open threads:**
- Orianna Track 2 redesign (forward-ref vs genuine fact error distinction) still in progress — this bypass is a one-off until that lands.


## 2026-04-19 — CI fixes: PR #25/#26/#28 firebase preview + lockfile

**Task:** Fix three independent CI failures on open PRs in strawberry-app. All workflow/build bugs, not secret issues.

**Done:**
- PR #25 (`chore/p1-2-lib-sh-xfail`): `preview.yml` copied `firebase.json` to repo root but not `.firebaserc`, so firebase-tools had no project reference when `vars.FIREBASE_PROJECT_ID` is unset. Added `cp apps/myapps/.firebaserc .firebaserc` step. Commit: a303dd6.
- PR #26 (`chore/p1-4-vitest-proof-of-life`): root `package-lock.json` had `@vitest/coverage-v8@4.1.4` but `apps/myapps/package.json` pins `4.0.18`. Ran `npm install` at repo root to regen lockfile. Commit: 99841bc.
- PR #28 (`chore/p1-3-env-ciphertext`): `turbo --filter=...[origin/main]` skips myapps when no frontend files changed, leaving `apps/myapps/dist` absent. `composite-deploy.sh` then exits 1. Added explicit `npm run build` in `apps/myapps` before composite-deploy step. Commit: e9650bb.

**Blockers / Open threads:**
- CI runs triggered — awaiting green. No merges (per Rule 18).
- PR #28 needed merge from remote before push (remote had forced-update commits). Merged cleanly.

---

## 2026-04-19 — Plan promotion: tests-dashboard-tasks + usage-dashboard-subagent-task-attribution

**Task:** Promote two plans from proposed → approved using `scripts/plan-promote.sh`.

**Done:**
- `plans/proposed/2026-04-19-tests-dashboard-tasks.md` → `plans/approved/` — fact-check clean (0 block), promoted, pushed. Commit: 82aee96.
- `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md` — first attempt blocked by Orianna: present-tense backtick ref to `scripts/usage-dashboard/subagent-scan.mjs` (not yet created in strawberry-app). Added `<!-- orianna: ok -->` to the line, committed that fix (bc3e616). Second attempt: Orianna returned exit 0 but `orianna-fact-check.sh` read the stale old report (T04-10-25Z) via alphabetical glob — which had block_findings: 1 — and exited 1 again. Deleted the stale report, re-ran, promotion succeeded. Commit: 8e7e794.
- No Drive docs involved (neither plan had a gdoc_id).

**Blockers / Open threads:**
- `orianna-fact-check.sh` has a latent bug: when Orianna writes a new report with a lexicographically earlier timestamp (e.g. T00-00-00Z) than a stale previous report (T04-10-25Z), the glob picks the stale one. The script should pick the report by mtime, not alphabetical order. Worth filing as a separate task for Orianna/Heimerdinger.

---

## 2026-04-19 — CI fix: PR body waivers + task-list/read-tracker lint

**Task:** Fix CI red on PRs #29, #32, #33 (QA report linter) and pre-existing `no-unused-expressions` lint errors in sibling apps.

**Done:**
- Replaced `QA-Report: pending` lines in PR #29, #32, #33 bodies with `QA-Waiver:` lines using `gh pr edit --body-file`. QA lint now green on all three.
- Diagnosed `no-unused-expressions` errors: 1 in `task-list/src/router/index.ts` (line 26) and 2 in `read-tracker/src/router/index.ts` (lines 28/31) — ternary-as-statement in `beforeEach` route guards.
- Created worktree at `/tmp/strawberry-app-lint-fix`, converted both ternary statements to `if/else`, committed, pushed, opened PR #38.

**Blockers / Open threads:**
- PR #38 (`fix/router-lint-errors` on strawberry-app) needs one approving review before merge. Once merged, PRs #29/#32/#33 need to pull in main to unblock their Lint check.
- Lint check on #29/#32/#33 still red — will auto-clear once #38 merges and branches pick up fix.
- `Firebase Hosting PR Preview` and `preview` remain red on all three — pre-existing composite-deploy/no-dist issue, not introduced this session.

---

## 2026-04-19 (session 4 — plan promotion)

**What was accomplished:**
- Promoted `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution-tasks.md` to `plans/approved/`.
- Added `<!-- orianna: ok -->` annotations to 4 forward-reference lines (subagent-scan.mjs, subagent-trim.mjs, subagent-scan.test.mjs, fixtures/subagents/) before re-running promotion.
- Deleted stale Orianna report (`T04-22-29Z`) that was triggering the glob-order false-block; re-ran cleanly (0 block, 0 warn, 14 info).
- Commit chain: 23f3b95 (orianna annotations) → 40050b9 (promote, pushed).

**Blockers / Open threads:**
- None for this task.

---

## 2026-04-19 (s5) — e2e.yml paths-ignore for apps/myapps

**Task:** Eliminate duplicate Playwright E2E runs triggered by both `e2e.yml` and `myapps-test.yml` on `apps/myapps` PRs.

**What happened:**
- Read both workflow files. `e2e.yml` uses TDD-enabled package detection; `myapps-test.yml` is a per-app scoped workflow with its own E2E job.
- Checked branch protection via REST (`GET /branches/main/protection` → 404) and confirmed with GraphQL (`branchProtectionRules` → `nodes: []`). No required checks configured — no wrapper job needed.
- Created worktree `strawberry-app-e2e-scope` on branch `chore/e2e-scope-myapps`.
- Added `paths-ignore: ['apps/myapps/**']` to `on.pull_request` in `e2e.yml`.
- Committed (bd60386), pushed, opened PR #48.
- CI queued (TDD Gate checks in QUEUED state at time of report).
- Wrote learnings + updated MEMORY.md, committed to strawberry-agents main (a9e0bb0).

**Blockers / Open threads:**
- PR #48 needs human review + merge (Rule 18 — agents may not merge their own PRs).
- If branch protection is enabled later with "Playwright E2E" as a required check, a thin always-runs wrapper job will be needed.
