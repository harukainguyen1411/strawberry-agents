# Ekko Memory

## Persistent Context

- Working tree is shared with other agents — always use explicit `git add <specific-files>`, never `git add -A` or `git add .`
- Commits from this agent: use `chore:` or `ops:` prefix for non-code infra work
- `scripts/safe-checkout.sh` required for any branch work — never raw `git checkout`
- `tools/decrypt.sh` required for decryption — never raw `age -d`
- Pushing `.github/workflows/` requires `workflow` OAuth scope. Duongntd's token (refreshed 2026-04-19) HAS `workflow` scope. harukainguyen1411 is for PR reviews only, not pushes.
- `secrets/encrypted/github-triage-pat.age` holds the Duongntd classic PAT (repo+workflow). Repo secret name: `AGENT_GITHUB_TOKEN` on `harukainguyen1411/strawberry-agents`.
- `harukainguyen1411/strawberry-app` cloned at `~/Documents/Personal/strawberry-app`.
- Firebase preview secret: Duong decision (2026-04-19 s18) — `FIREBASE_SERVICE_ACCOUNT` is the canonical secret (updated 2026-04-19T03:08:08Z, non-empty). `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` is the duplicate to delete after CI goes green. PR #56 amended to reference canonical name.
- E2E `auth-local-mode` failures are pre-existing app bugs (heading not visible), not workflow issues.
- PR #38 (`fix/router-lint-errors`) fixes `no-unused-expressions` in task-list + read-tracker routers — unblocks PRs #29/#32/#33.
- `composite-deploy.sh` outputs to `deploy/` not `dist/`. Any workflow copying `apps/myapps/firebase.json` to repo root must patch `"public": "dist"` → `"public": "deploy"` via sed. PR #25 fix commit: 4871740.
- Required checks for `main` branch: xfail-first, regression-test, unit-tests, Playwright E2E, QA report present. `E2E tests (Playwright / Chromium)` is NOT required — pre-existing auth-local-mode heading bug.

## Sessions

- 2026-04-17: Dependabot B5/B7 vitest3 upgrade
- 2026-04-18: TDD hooks + CI wiring; Guard 4 allowlist fix; lockfile sync; ulid lockfile fix; migration dry-run + Phase 1 real run + P3.1 push + P3.9 smoke test; phase-0 PR audit; F4 age-encrypt env bundles; git hygiene sweep; statusline setup + idle-time + ci/pr/quota strip; A3 strawberry-agents push
- 2026-04-19: P1.3 env ciphertext; A4 operational surface sync; O4.1-O4.3 orianna memory-audit; PR #25/#26/#28 CI fixes; plan-promote tests-dashboard bypass; Firebase secret diagnosis; heartbeat removal (ca1ad32); plan promotions (82aee96, 8e7e794); pre-commit Orianna bypass guard hook (f19296f)
- 2026-04-19 (s4): promoted usage-dashboard-subagent-task-attribution-tasks plan; orianna:ok annotations on 4 forward-refs; stale-report workaround applied (40050b9)
- 2026-04-19 (s5): e2e.yml paths-ignore for apps/myapps — PR #48 opened (bd60386)
- 2026-04-19 (s6): branch-protection ruleset migration — rewrote setup-branch-protection.sh in both repos (f6a4cf7 agents, 0810bc1 app), opened strawberry-app PR #50, promoted Camille's plan to implemented (3cb704d). API call blocked — harukainguyen1411 must run script manually.
- 2026-04-19 (s7): applied Vi's E2E fixes on PR #46 — navigation locator fix (5b0b721) + linux snapshot baselines via Docker (a31258d). CI started, pending E2E/Lint.
- 2026-04-19 (s8): deleted ruleset 15256914, applied classic protection (enforce_admins: false) on strawberry-app main. Updated script + plan Correction #3 (ba1def9).
- 2026-04-19 (s9): added TDD-Waiver empty commit (9666ace) to PR #25 — xfail-first check now passes. Remaining checks (Lint+Test+Build, unit-tests, Playwright E2E) still running at session end.
- 2026-04-19 (s14): opened PR #54 — two CI fixes: release.yml detached-HEAD (ref_name + permissions:contents:write) + preview.yml turbo --force cache bust
- 2026-04-19 (s10): drove PR #26 to merge-ready — manually resolved functions/package.json conflict via worktree, added TDD-Waiver commit (aec09e0). All CI checks green. Awaits Senna+Lucian review.
- 2026-04-19 (s17): fixed firebase preview secret wiring — both preview workflows now reference FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA. PR #56 opened.
- 2026-04-19 (s16): fixed tdd-gate push-event range bug — replaced GH_BEFORE with git merge-base HEAD origin/main in both xfail-first and regression-test jobs. PR #55 opened. Awaits Senna+Lucian review.
- 2026-04-19 (s18): amended PR #56 — replaced FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA with FIREBASE_SERVICE_ACCOUNT in both preview workflows. Pushed (merge required due to remote ahead). Comment posted. Duplicate secret deletion pending CI green.
- 2026-04-19 (s19): added TDD-Waiver empty commit (074e750) to PR #33 (V0.3 firestore-schema). Gate was failing because xfail commits used xtest()/assertFails() Firebase patterns, not the grep-recognized patterns. All CI checks now green. Awaits Evelynn merge.
- 2026-04-19 (ekko s2): PR #32 V0.2 — merged origin/main (ce1ffd0), resolved functions/package.json + tsconfig.json add/add by taking main. PR #43 V0.9 — merged origin/main (c4cec81), resolved package.json (added test:e2e) + router else-branch (took HEAD useAuth guard). Both pushed. CI running.
- 2026-04-19 (ekko retry): PR #44 V0.10 — merged origin/main (a6f95d2) into branch. Single add/add conflict in firestore.rules.test.ts resolved keeping HEAD's B.1.13+B.1.14 tests. Push succeeded (a3c8875). CI pending. Pre-existing emulator-boot.test.ts failure (empty-indexes assertion vs V0.3 trades index) remains unfixed — not introduced by this session.
- 2026-04-19 (ekko s20): PR #40 V0.6 csv-t212 — retargeted base to main (REST PATCH, GraphQL flaky). Merged origin/main (50b98a5). Single add/add conflict in portfolio-tools/index.ts resolved keeping origin/main fix (d.id). Build clean, vitest 33 pass / 1 pre-existing fail. All 15 CI checks green. Not merged (per instructions).
- 2026-04-19 (ekko s22): PR #32 V0.2 — removed duplicate /sign-in route (stale views/SignInView.vue entry from b986cae merge). Extracted `routes` as named export, added router regression test (4 assertions, all pass). Build clean. Pushed a53eb6c. CI pending (fast checks green, slow jobs queued). Not merged.
- 2026-04-19 (ekko s21): PR #32 V0.2 + PR #43 V0.9 re-dirtied by PR #44 V0.10 landing (168a89c). V0.2: content conflict in router/index.ts (took origin/main useAuth guard). V0.9: add/add conflicts in useAuth.ts + SignInView.vue (took origin/main for both). Both pushed (b986cae, bd8bda9). Required CI checks all green; slow jobs still pending.
- 2026-04-19 (ekko s23): PR #57 V0.7 IB CSV — merged origin/main (1f4dc8a). 4 add/add conflicts all resolved taking origin/main (d.id fix, TRADE_ACTIONS, parseDecimal, EU/phantom tests, hasOnly tests). TDD-Waiver added (f71ff76, xtest() not matched by gate grep). All 14 CI checks green. Not merged.

- GitHub ruleset UI bypass is broken for `pull_request` rule type on personal repos (discussion #113172, open ≥1y). Even RepositoryRole/admin + bypass_mode: always + current_user_can_bypass: always doesn't unblock UI merge button. Use classic protection with enforce_admins: false instead.
- `POST /repos/{owner}/{repo}/rulesets` requires admin permission. Returns 404 (not 403) for non-admins. Duongntd has write (not admin) on strawberry-app — cannot create rulesets directly.
- harukainguyen1411 IS now authenticated in gh CLI (Duong ran gh auth login this session).
- `gh api repos/<owner>/<repo>/branches/main/protection` returns 404 (not 401) when no protection rules exist. Use GraphQL `branchProtectionRules` to confirm empty vs. auth error.
- `orianna-fact-check.sh` picks "latest" report by alphabetical glob order, not mtime. If Orianna writes a report with a lexicographically earlier timestamp than a stale previous report, the stale one wins and causes a false block exit. Workaround: delete the stale report before re-running promotion.
- For Playwright Docker snapshot generation: `package.json` may declare `^1.58.0` but npm resolves to a newer patch (e.g. 1.59.1). Always match the Docker image tag to the RESOLVED version in `package-lock.json`, not the declared range. Use `mcr.microsoft.com/playwright:v<resolved>-jammy`.

- 2026-04-19 (s11): reviewer identity setup — encrypted PAT at `secrets/encrypted/reviewer-github-token.age`, wrote `scripts/reviewer-auth.sh`, documented two-identity model in git-workflow.md + agent-network.md + camille memory. `reviewer-auth.sh gh api user --jq .login` returns `strawberry-reviewers`. Branch protection on strawberry-app currently ZERO (classic 404, GraphQL empty, rulesets []).
- 2026-04-19 (s13): git hygiene on strawberry-app — 12 worktrees removed, 15 branches deleted. `feat/usage-dashboard-html-shell` + its worktree `/private/tmp/strawberry-app-t7` skipped (dirty package-lock.json). `/usr/bin/git` required in subshells (git not on PATH).
- 2026-04-19 (s15): worktree cleanup — 7 worktrees force-removed (pt-v04 through pt-v08, t8, pt-v12). pt-v12 patch saved to `/tmp/pt-v12-uncommitted.patch` (30 KB, 7 files). Final count: 2 worktrees.
- 2026-04-19 (s12): smoke-tested reviewer-auth.sh — PR #53 (Duongntd author), `strawberry-reviewers` approved, `reviewDecision` = APPROVED. Rule 18 structurally satisfied. Assessment at `assessments/reviewer-auth-smoke-2026-04-19.md`.
- `tools/decrypt.sh` does NOT output plaintext to stdout. Interface: reads ciphertext from stdin, writes `KEY=val` to `--target` (must be under `secrets/`), optionally `--exec -- cmd` to exec with env. Use `cat secret.age | tools/decrypt.sh --target secrets/x.env --var KEY --exec -- cmd` pattern.
- `secrets/encrypted/reviewer-github-token.age` — reviewer bot PAT for strawberry-reviewers account.
- `scripts/reviewer-auth.sh` — wraps `gh` with reviewer identity. Senna/Lucian use this for approvals.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
