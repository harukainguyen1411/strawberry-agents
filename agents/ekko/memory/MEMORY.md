# Ekko Memory

## Persistent Context

- Working tree is shared with other agents (Jhin, Viktor, Vi, etc.) — always use explicit `git add <specific-files>`, never `git add -A` or `git add .`
- Commits from this agent: use `chore:` or `ops:` prefix for non-code infra work
- `scripts/safe-checkout.sh` required for any branch work — never raw `git checkout`
- `tools/decrypt.sh` required for decryption — never raw `age -d`

## Completed Tasks

- **2026-04-18 (P3.9 smoke test):** Smoke-tested strawberry-app post-migration. PR #18 opened at `harukainguyen1411/strawberry-app/pull/18`. 10 green workflows, 1 red (`Preview` — pre-existing composite-deploy no-dist error, not a migration regression). All critical checks pass. Report: `assessments/2026-04-18-p3-9-smoke-report.md`. Live strawberry commit: `184eb7f`. PR left open for Duong to merge.

- **2026-04-18 (P3.1 migration push):** Squashed 7 commits to 1 on `/tmp/strawberry-app-migration`, force-pushed to `harukainguyen1411/strawberry-app`. Remote SHA: `344267362ab469cd8fc947ef7d91c6cc935a8368`. Commit count = 1, 795 recursive tree objects (605 files). Gitleaks 0 findings. Report: `assessments/2026-04-18-p3-1-push-report.md`. Live strawberry commit: `f9df72c`.



- **2026-04-18 (P1 migration real run):** Built filtered tree for `harukainguyen1411/strawberry-app` at `/tmp/strawberry-app-migration`. Tagged base SHA `af2edbc0` as `migration-base-2026-04-18`. Orphan commit `1b6865f` — 1 commit, 602 files, 0 gitleaks leaks on HEAD. Old origin history has 10 findings (not blocking — all in private paths, none in orphan). Telegram bot token in old private history flagged for rotation. Report: `assessments/2026-04-18-p1-filter-report.md`. Ready for Phase 2 (Viktor).


- **2026-04-18 (phase-0 audit):** Audited all 13 plan PRs. 11 already MERGED (mix of dual-green and admin-bypass billing-blocked). 2 OPEN: #152 (real CI failures, needs fix), #161 (billing-hardstop CI, no review — needs APPROVED before merge). 0 admin-merge candidates. Audit file: `assessments/2026-04-18-phase-0-merge-queue.md`. Commit: `e0c4508`.

- **2026-04-18 (ulid lockfile fix):** `dashboards/server/package.json` declares `ulid@^3.0.2`; root lockfile was missing it. `npm install --ignore-scripts` added 19 packages. `npm ci` now clean. Commit `dbc1be1`, pushed to main.


- **2026-04-18 (migration dry-run):** Ran Phase 1+2 dry-run for public-app-repo migration. Bare clone → filter → squash → gitleaks → grep sweep → build sanity. Result: 0 gitleaks findings, 17 files need slug rewrite in Phase 2, `npm ci` lockfile desync is pre-existing. Report: `assessments/2026-04-18-migration-dryrun.md`. Commit: `e1e7417`.

- **2026-04-18 (Guard 4 fix):** Patched pre-commit Guard 4 allowlist to add `agents/*/memory/*`, `agents/*/journal/*`, `agents/*/learnings/*`, `agents/*/transcripts/*`, `plans/*` — matching Guards 1-3. Also pruned 11 stale worktrees including `strawberry-b14/`. Commit SHA: `642c2db`.

- **2026-04-18:** Lockfile sync check — `npm install` on main produced zero diff; `@types/node@25.6.0` already present in HEAD lockfile. No commit needed. CI failures on open PRs are branch-local, not a main issue.

- **F4 (2026-04-18):** Generated INGEST_TOKEN, age-encrypted prod+staging env bundles for test-dashboard service, committed to main as `secrets/encrypted/dashboards.prod.env.age` and `secrets/encrypted/dashboards.staging.env.age`. SHA: `4a3fdc0`.
- **2026-04-18:** Git hygiene sweep — removed stale branches, pruned remotes
- **C2 (2026-04-18):** Pre-commit hook wiring for dashboards pnpm — PR #165. Hook detects `dashboards/**` staged changes and runs `pnpm -C <pkg> test:unit`; non-dashboards TDD packages keep `npm run`. Xfail in `scripts/hooks/test-hooks.sh`.
- **2026-04-18 (it.fails fix):** Both xfail detectors (`tdd-gate.yml` line 74 + `pre-push-tdd.sh` line 72) updated to match `it\.fails|it\.failing`. Vitest uses `it.fails`; Playwright uses `it.failing`. Both now accepted. Pushed to main as `11d4566`.
- **2026-04-18:** TDD hooks + CI wiring task completed
- **2026-04-17:** Dependabot B5/B7 vitest3 upgrade
- **2026-04-18 (P0.0 preflight):** Created harukainguyen1411/strawberry-app (public) and harukainguyen1411/strawberry-agents (private). Configured Actions permissions, workflow permissions, Dependabot alerts + auto-fixes on both. Commit fa6099a. Awaiting Duong Firebase GitHub App install before Phase 1.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
