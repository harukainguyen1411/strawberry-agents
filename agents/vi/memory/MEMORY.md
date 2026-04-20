# vi Memory

- [Vitest 4.x API: it.fails not it.failing](../learnings/2026-04-18-xfail-seed-cluster-vitest4-api.md) — it.failing removed in v4; it.fails is correct; bodyless calls throw; canonical fix in #170
- [Vitest xfail config + merge hygiene](../learnings/2026-04-18-vitest-xfail-config-and-merge-hygiene.md) — never exclude xfail files; merge origin/main before push
- [CI billing-block stand-down](../learnings/2026-04-18-ci-billing-block-stand-down.md) — simultaneous all-red across all PRs = check Actions billing before workflow regression
- [PR170 CI fixes + stale worktree](../learnings/2026-04-18-xfail-cluster-close-pr170-ci-fixes.md) — fetch before asserting branch state; unit-tests.yml needs npm install; QA-Waiver required; take --theirs for shared test fixture conflicts

- [O6 Orianna smoke tests](../learnings/2026-04-18-orianna-o6-smoke-tests.md) — LLM path broken (wrong CLI flags); bash fallback works; gate integration correct; dogfood reveals 1 real stale path + 2 false positives (brace expansion, future outputs)
- [Orianna v1 finalization](../learnings/2026-04-18-orianna-v1-finalization.md) — O6.5 PASS (exit 0, report committed fae01e9); ADR dogfood PASS (block=0); tasks plan dogfood BLOCKED (block=2: stale body text O6.8 lines 712/731 + Firebase GitHub App meta-example); report-picker bug in orianna-fact-check.sh (prefix match picks tasks report instead of ADR report); promotion halted

## Sessions
- 2026-04-18: xfail cluster + TDD discipline — seeded 7-item xfail cluster across B1/B3/F1/F2/F3/G1; found and fixed it.failing→it.fails; fixed #170 CI (lockfile, QA-Waiver, workflow npm install); all cluster items closed
- 2026-04-18: Orianna O6 smoke tests — ran O6.1-O6.8; found LLM CLI flag bugs; bash fallback solid; dogfood blocks on 1 real + 2 false positives
- 2026-04-18: Orianna v1 finalization — O6.5 pass; ADR dogfood pass; tasks plan blocked (2 blocks); promotion halted

- [P1.2 bats xfail + P1.4 vitest](../learnings/2026-04-19-p1-2-p1-4-tdd-setup.md) — vacuous-pass trap for negative-assertion tests; pre-commit secrets guard false positive on `age -d` in grep patterns; G2 gate fixture collision; Firebase module mocking order for Vitest
- [PR #25/#26 review fixes](../learnings/2026-04-19-pr25-pr26-review-fixes.md) — run --separate-stderr required for $stderr; age -d in test names triggers hook; multiline age detection via awk; bare-deploy gate false-positive filtering; onCall mock returning raw handler for real behavior tests

## Sessions
- 2026-04-19: P1.2 bats xfail suite + P1.4 Vitest proof-of-life — wrote 26-test bats suite for _lib.sh (24/26 xfail correctly); landed 2-commit Vitest proof-of-life for BEE_INTRO_MESSAGE; both branches pushed (chore/p1-2-lib-sh-xfail SHA 40463a0, chore/p1-4-vitest-proof-of-life SHAs 43437dc + 4765882)
- 2026-04-19: PR #25/#26 Jhin review fixes — addressed C2/C4/I2/I3 on #25 and C1/I2 on #26; 29/29 bats + 4/4 vitest; pushed SHAs 8c68ae5 (p1-2) and dad412f (p1-4)

- [PR #26 round 2 fixes](../learnings/2026-04-19-pr26-round2-fixes.md) — permission-denied test accessed wrong branch (makeRequest(undefined) hits unauthenticated, not permission-denied); lockfile drift requires deleting lockfile + overrides in root package.json; lint-staged can revert JSON edits during commit — use Write tool + verify staged diff before committing
- [Playwright usage-dashboard E2E](../learnings/2026-04-19-playwright-usage-dashboard-e2e.md) — Tailwind flex overrides hidden attr (use toHaveAttribute not toBeHidden); health probe race (wait >300ms); fixture expiry horizon; npx serve for static webServer; worktree needs npm install
- [e2e.yml Firebase boot regression](../learnings/2026-04-19-e2e-workflow-firebase-boot.md) — missing npm ci (exit 127) + missing VITE_FIREBASE_* env vars (app blank) silently hidden until tdd.enabled set; fix: add npm ci step + secrets to run step; cross-check against sibling workflow

## Sessions
- 2026-04-19: PR #26 round 2 — fixed misnamed permission-denied test (now calls with real UID + asserts permission-denied/not_authorized_for_bee), fixed lockfile drift (deleted lockfile, added root override vitest=4.0.18, pinned apps/myapps workspace); tip SHA ef7c188
- 2026-04-19: T10 Playwright smoke — wrote 11-test suite for usage-dashboard static-load path; 11/11 green; found CSS ordering bug (hidden+flex); QA report filed; PR #39 open (strawberry-app)
- 2026-04-19: P1.4 CI fix — pushed 2 unpushed commits (dfb6f49 lockfile regen + ef7c188 vitest workspace pin) + lint fix (a5be709 remove unused beforeEach); PR #26 updated with QA-Waiver; Unit Tests/TDD Gate/PR Body Linter/E2E all green; remaining failures pre-existing (rollup linux binary, portfolio-tracker lint, Firebase hosting)
- 2026-04-19: e2e.yml Firebase boot fix — PR #46 (tdd-gate-enable-functions) exposed two pre-existing defects in e2e.yml: missing npm ci (exit 127) and missing VITE_FIREBASE_* env vars (firebase/config.ts throws → blank page → toBeVisible fails). Fixed in PR #47 (fix/e2e-workflow-npm-install).
- 2026-04-19: PR #46 E2E diagnosis — two distinct failures remain on beca79d: (A) 7 visual-regression tests fail because snapshots committed as *-darwin.png but CI expects *-linux.png; (B) navigation test looks for link name 'MyApps' but AppHeader has no such link (uses $t('common.home')). Both regressions from my 598d0eb commit (T10 session). Duong's beca79d is unrelated/correct. Fix A: generate linux snapshots in CI or linux docker. Fix B: change locator to 'Dark Strawberry home' aria-label or /home/i.

- [Orianna gate v2 xfail tests](../learnings/2026-04-20-orianna-gate-v2-xfail-tests.md) — xfail guard pattern for absent scripts; sourceable lib test pattern; T5.7 multi-phase smoke harness; T7.2 hermetic PATH offline-fail; cross-platform date fallback
- [Orianna smoke 11/11 debug](../learnings/2026-04-20-orianna-smoke-11-11-debug.md) — body hash frozen at signing; test results must be final before in_progress sign; plan-promote.sh must handle all forward lifecycle stages; REPO env var must be honored in _lib_gdoc.sh

## Sessions
- 2026-04-20: Orianna gate v2 xfail tests — wrote T5.1–T5.7, T7.2, T11.1; 38 cases across 7 scripts + 1 stub; PR #5 open (feat/orianna-gate-v2-tests); all scripts confirmed xfail-on-absent
- 2026-04-20: Orianna smoke 11/11 debug — fixed 4 failures in test-orianna-lifecycle-smoke.sh; 3 commits (79e2298 + 3ddac26 + 9541b0c); 11/11 PASS

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
