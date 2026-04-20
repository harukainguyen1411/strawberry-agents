# Ekko Memory

## Persistent Context

- Working tree shared — always `git add <specific-files>`, never `git add -A` or `git add .`
- `scripts/safe-checkout.sh` for branches — never raw `git checkout`
- `tools/decrypt.sh` for decryption — never raw `age -d`
- `scripts/reviewer-auth.sh` MUST be run from strawberry-agents dir — decrypt.sh refuses targets outside its secrets/
- `scripts/reviewer-auth.sh` — wraps `gh` with strawberry-reviewers identity. Run from strawberry-agents dir.
- `harukainguyen1411/strawberry-app` cloned at `~/Documents/Personal/strawberry-app`
- Required checks for main: xfail-first, regression-test, unit-tests, Playwright E2E, QA report. `E2E tests (Playwright / Chromium)` is NOT required — pre-existing auth-local-mode heading bug.
- `harukainguyen1411/strawberry-app` main: 2-approval gate active (required_approving_review_count=2) as of 2026-04-19 s34. Use `--input -` with JSON body for gh api PUT branch protection (--field fails for nested objects).
- Duongntd auth has NO admin on harukainguyen1411/strawberry-agents (pull/push/triage only). Branch-protection writes require harukainguyen1411 account (Duong-manual).
- `tools/decrypt.sh`: reads ciphertext stdin, writes `KEY=val` to `--target` (must be under `secrets/`). Use `cat secret.age | tools/decrypt.sh --target secrets/x.env --var KEY --exec -- cmd`.
- T212 API: Basic auth (API_KEY_ID:SECRET_KEY base64). Live URL: https://live.trading212.com. See learnings/2026-04-19-t212-api-fixtures.md for full field/shape reference.
- GitHub branch protection (classic or rulesets) on private repos requires GitHub Pro — free-plan accounts get 403.

- Global git hooksPath (`~/.config/git/hooks/pre-commit`) runs `$REPO_ROOT/scripts/hooks/pre-commit-*.sh`. Hooks are active even if `.git/hooks/` is empty. Check `git config --global core.hooksPath` when debugging unexpected hook behavior.
- `git commit --trailer` appends trailers AFTER the pre-commit hook runs. COMMIT_EDITMSG at pre-commit time holds the PREVIOUS commit's message. Always embed trailers directly in `-m` message body when pre-commit hooks need to inspect them.
- `git add <specific-file>` before every commit — staged files from failed prior operations linger and get swept into unrelated commits.

## Sessions

- 2026-04-20 (ekko s-audit): CLAUDE.md cleanup — Lux audit items 1-5. rule5 decision tree `98f33b7`, end-session skill DMI fix `0904844`, rule19 anchor `4d4e732`, plan-fetch.sh+google-oauth-bootstrap.sh deleted (concurrent session cf2b5f2), end-session refuse-empty-arg `cd6a2ab`. All pushed.


- 2026-04-19 (ekko s29): added `--lane <name>` to reviewer-auth.sh (Phase 3 reviewer-identity-split). Commit 306fed2. Default lane unchanged.
- 2026-04-19 (ekko s30): encrypted senna PAT → reviewer-github-token-senna.age; round-trip verified strawberry-reviewers-2; shredded plaintext. Commit 95064e1.
- 2026-04-19 (ekko s31): Phase 4 dry-run — PR #3 on strawberry-agents; Senna→strawberry-reviewers-2, Lucian→strawberry-reviewers; two distinct approvals confirmed; PR closed, branch deleted.
- 2026-04-19 (ekko s32): Phase 7 branch-protection attempt — stopped; Duongntd lacks admin on harukainguyen1411/strawberry-agents. Duong-manual step required.
- 2026-04-19 (ekko s33): Phase 7 retry as harukainguyen1411 — 403; branch protection on private repos requires GitHub Pro. Plan blocked.
- 2026-04-19 (ekko s34): Applied 2-approval gate to harukainguyen1411/strawberry-app main. Verified count=2, all 5 contexts preserved.
- 2026-04-19 (ekko s35): Moved .claude/agents/_retired/ → .claude/_retired-agents/ to hide retired agents from harness scanner. Updated 3 reference files. Pushed via harukainguyen1411 reviewer PAT.
- 2026-04-19 (ekko s36): Closed 11 non-Dependabot PRs in Duongntd/strawberry (Phase 4 migration), deleted 11 feature branches. 19 Dependabot PRs left open.
- 2026-04-19 (ekko s37): Full workspace sweep. /tmp migration scratch trees + secrets scripts deleted. All 12 strawberry-app worktrees removed (all merged/closed), 13 local branches deleted, main fast-forwarded 39 commits to 4ea1884. Old strawberry clone at ~/Documents/Personal/strawberry/ is DIRTY (2 modified files + 1 untracked) — not deleted, awaiting Duong decision.
- 2026-04-19 (ekko s38): T212 API fixtures generated from live API (cash/portfolio/orders). order.id, fill.id, nextPagePath redacted. T212.env encrypted to T212.env.age (round-trip sha256 verified), plaintext deleted. PR #61 open on strawberry-app. Worktree at ~/Documents/Personal/strawberry-app-t212.
- 2026-04-19 (ekko s39): Merged PR #61 (chore: T212 fixtures + encrypted key). All 15 checks green, APPROVED (Senna+Lucian). Merge SHA: 3b98f34de18084e9217439f3229fea23271b0ec1.
- 2026-04-19 (ekko s40): Updated PR #62 branch (phase1-darkstrawberry-apps-rename) — merged origin/main, resolved rename-vs-add conflict for T212 fixtures (moved from apps/myapps/ ghost dir to apps/darkstrawberry-apps/), pushed ff372ed. mergeStateStatus: BLOCKED (needs reviews/CI), mergeable: MERGEABLE.
- 2026-04-20: Promoted 2026-04-20-orianna-gated-plan-lifecycle.md to approved via plan-promote.sh. Orianna gate: 0 blocks, CLEAN. Commit 618904b pushed to main.
- 2026-04-20 (ekko — Sona dispatch): Genericised memory-consolidate and filter-last-sessions scripts to accept `<secretary>` arg. scripts/memory-consolidate.sh replaces scripts/evelynn-memory-consolidate.sh. Commit 97a4fb3. BLOCKER: .claude/agents/evelynn.md edit denied by harness — evelynn.md still calls old scripts. Duong must update manually (see learnings/2026-04-20-script-parameterisation.md).
- 2026-04-20 (ekko — Sona dispatch): Refreshed missmp/api checkout for PR #40 — already at latest HEAD 27e6e06, no new commits, reference/ unchanged.
- 2026-04-20: Promoted 2026-04-20-agent-pair-taxonomy.md to approved. Orianna: 0 blocks, 0 warns, 6 info. Commit 8fa6821.
- 2026-04-20 (ekko): Closed PR #4 (billing block — all CI queued 0s); cherry-picked f223542+13db201 onto main as chore: infra commits. Landed at 7735020. 24/24 bats green.
- 2026-04-20 (ekko): Closed PR #5 strawberry-agents (billing block — all CI 4-5s); local test run 38/38 xfail exit 0; cherry-picked 8 commits onto main. Range 3ad163d..9b49d89.
- 2026-04-20 (ekko): Bug 1 — added Orianna-Bypass trailer reader to pre-commit-plan-authoring-freeze.sh (consistent with promote-guard §D9.1); COMMIT_EDITMSG resolution fixed to use absolute GIT_DIR; 6-case regression test added. Commit 90b0f53. Bug 2 — fixed mktemp --suffix=.md (Linux-only) in plan-publish.sh (now deleted). Commit 3b1f191. Bug 3 / re-publish: moot — Drive mirror feature retired.
- 2026-04-20 (ekko): Drive mirror feature removed entirely. Deleted plan-publish.sh, plan-unpublish.sh, test_plan_gdoc_offline.sh, architecture/plan-gdoc-mirror.md. Stripped Drive unpublish step from plan-promote.sh. Updated CLAUDE.md rule #7, key-scripts.md, platform-parity.md, agent-network.md, evelynn.md, orianna-gated-plan-lifecycle.md. Commits 51e2264 + 136c3a2.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
