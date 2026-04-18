# Ekko Memory

## Persistent Context

- Working tree is shared with other agents (Jhin, Viktor, Vi, etc.) — always use explicit `git add <specific-files>`, never `git add -A` or `git add .`
- Commits from this agent: use `chore:` or `ops:` prefix for non-code infra work
- `scripts/safe-checkout.sh` required for any branch work — never raw `git checkout`
- `tools/decrypt.sh` required for decryption — never raw `age -d`
- Pushing `.github/workflows/` requires `workflow` OAuth scope. `Duongntd` token lacks it. Use `gh auth token --user harukainguyen1411` as push credential: `git push https://harukainguyen1411:<token>@github.com/harukainguyen1411/strawberry-agents.git main`

## Persistent Context — strawberry-app

- `harukainguyen1411/strawberry-app` cloned at `~/Documents/Personal/strawberry-app` (HEAD `dc64379`, 2026-04-18).
- `apps/` has 10 subdirs: `coder-worker`, `contributor-bot`, `deploy-webhook`, `discord-relay`, `landing`, `myapps`, `platform`, `private-apps`, `shared`, `yourApps`. No `bee` dir.

## Completed Tasks

- **2026-04-18 (A3 strawberry-agents push):** Pushed filtered tree to `harukainguyen1411/strawberry-agents`. Final SHA: `650079a845f18e938d0c28f57eb6530911722d0d` (cherry-picked A2 commit onto main after detached HEAD divergence). Secrets set: `AGE_KEY` (from secrets/age-key.txt), `AGENT_GITHUB_TOKEN` (from secrets/github-triage-pat.txt). Branch protection BLOCKED — GitHub free plan does not allow branch protection on private repos (HTTP 403). Deviation noted; requires GitHub Pro upgrade or repo made public. Stopped at A3 per instructions.



- **2026-04-18 (statusline ci/pr/quota strip):** Stripped `ci`, `prs`, and `quota` fields from `~/.claude/statusline-command.sh`, along with all cache helpers (`cache_read`, `cache_write`, `cache_refresh_bg`, `CACHE_DIR`). Remaining fields: `git`, `model`, `ctx`, `cost`, `todos`, `idle`. Backup at `~/.claude/statusline-command.sh.bak.20260418`. Stale cache files at `/tmp/claude-statusline-cache/{ci_main,pr_queue,quota}` should be manually removed.

- **2026-04-18 (statusline ci/pr/quota add):** Originally added `ci:✓/✗/~/? ` (gh run list, branch-keyed cache), `prs:A/R` (gh pr list, omit if 0/0, review-requested via --search not --review-requested flag), `quota:N%` (ccusage blocks --json, time-based % of 5h window, skip if ccusage absent). All used 60s TTL disk cache at `/tmp/claude-statusline-cache/`. (These fields were later removed.)


- **2026-04-18 (statusline idle-time):** Extended `~/.claude/statusline-command.sh` with idle-time field (section 6). Added `UserPromptSubmit` hook in `~/.claude/settings.json` writing `date +%s` to `/tmp/claude-last-prompt-<session_id>`. Colors: dim grey <1m, white 1-5m, yellow 5-30m, red 30m+. Format: `Ns`/`Nm`/`Nh Nm`. Hook reads `$CLAUDE_HOOK_INPUT` env var (not stdin).

- **2026-04-18 (statusLine setup):** Created `~/.claude/statusline-command.sh` and added `statusLine` key to `~/.claude/settings.json`. Script shows: git branch+dirty+ahead/behind, worktree [wt], model, ctx % remaining (color-coded), cost (color-coded), pending todos from `~/.claude/todos/<session_id>.json`.


- **2026-04-19 (A4 follow-up operational surface sync):** Rsynced 104 missing files (scripts/, tools/, .github/) from archive to strawberry-agents. Commit SHA: e5c51a7. Push blocker: Duongntd token lacks workflow scope — resolved by pushing via harukainguyen1411 account token. scripts/gh-audit-log.sh confirmed present.

- **2026-04-19 (O4.1-O4.3 orianna memory-audit):** Built three O4 deliverables:
  `agents/orianna/prompts/memory-audit.md` (pinned audit prompt), `scripts/orianna-memory-audit.sh`
  (POSIX script — exits 2 if claude CLI absent, fetches fresh SHAs, commits+pushes report),
  `agents/orianna/runbook-reconciliation.md` (5-step ADR §4.4 runbook). TDD seed at
  `agents/orianna/learnings/2026-04-19-o4-tdd-stale-seed.md` with two known-stale paths.
  Commit: e66416f.

- **2026-04-19 (A1 strawberry-agents filter):** Ran `git filter-repo --invert-paths` on fresh bare clone at `migration-base-2026-04-18`. Filtered tree at `/tmp/strawberry-agents-migration` — 914 commits preserved. 2 gitleaks findings (private paths, not blocking). secrets/encrypted/ verified. Report pre-committed by Viktor in `085b781`. Ready for Phase A2 (reference rewrite).


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
