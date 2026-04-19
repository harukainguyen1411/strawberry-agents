# Ekko Memory

## Persistent Context

- Working tree is shared with other agents — always use explicit `git add <specific-files>`, never `git add -A` or `git add .`
- Commits from this agent: use `chore:` or `ops:` prefix for non-code infra work
- `scripts/safe-checkout.sh` required for any branch work — never raw `git checkout`
- `tools/decrypt.sh` required for decryption — never raw `age -d`
- Pushing `.github/workflows/` requires `workflow` OAuth scope. Duongntd's token (refreshed 2026-04-19) HAS `workflow` scope. harukainguyen1411 is for PR reviews only, not pushes.
- `secrets/encrypted/github-triage-pat.age` holds the Duongntd classic PAT (repo+workflow). Repo secret name: `AGENT_GITHUB_TOKEN` on `harukainguyen1411/strawberry-agents`.
- `harukainguyen1411/strawberry-app` cloned at `~/Documents/Personal/strawberry-app`.
- Firebase preview secret: `FIREBASE_SERVICE_ACCOUNT` EXISTS on the repo but value is EMPTY — Duong must delete + re-add with actual JSON from Firebase console.
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

- GitHub ruleset UI bypass is broken for `pull_request` rule type on personal repos (discussion #113172, open ≥1y). Even RepositoryRole/admin + bypass_mode: always + current_user_can_bypass: always doesn't unblock UI merge button. Use classic protection with enforce_admins: false instead.
- `POST /repos/{owner}/{repo}/rulesets` requires admin permission. Returns 404 (not 403) for non-admins. Duongntd has write (not admin) on strawberry-app — cannot create rulesets directly.
- harukainguyen1411 IS now authenticated in gh CLI (Duong ran gh auth login this session).
- `gh api repos/<owner>/<repo>/branches/main/protection` returns 404 (not 401) when no protection rules exist. Use GraphQL `branchProtectionRules` to confirm empty vs. auth error.
- `orianna-fact-check.sh` picks "latest" report by alphabetical glob order, not mtime. If Orianna writes a report with a lexicographically earlier timestamp than a stale previous report, the stale one wins and causes a false block exit. Workaround: delete the stale report before re-running promotion.
- For Playwright Docker snapshot generation: `package.json` may declare `^1.58.0` but npm resolves to a newer patch (e.g. 1.59.1). Always match the Docker image tag to the RESOLVED version in `package-lock.json`, not the declared range. Use `mcr.microsoft.com/playwright:v<resolved>-jammy`.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
