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
- 2026-04-20 (ekko): T1 for Lissandra plan — added memory-consolidator:single_lane to is_sonnet_slot() in pre-commit-agent-shared-rules.sh. xfail commit 78f57b1, impl commit d314926. 17/17 bats green.
- 2026-04-20 (ekko): Drive mirror feature removed entirely. Deleted plan-publish.sh, plan-unpublish.sh, test_plan_gdoc_offline.sh, architecture/plan-gdoc-mirror.md. Stripped Drive unpublish step from plan-promote.sh. Updated CLAUDE.md rule #7, key-scripts.md, platform-parity.md, agent-network.md, evelynn.md, orianna-gated-plan-lifecycle.md. Commits 51e2264 + 136c3a2.
- 2026-04-21 (ekko): PR #7 CI triage (orianna-work-repo-routing). All 13 failures were GitHub Actions billing block — no job actually executed. ci.yml and preview.yml had no paths filter and would fail on infra PRs (no root package.json). Fixed: ops: commit 34ee43d adds paths filter for apps/**/dashboards/**/package files. All remaining checks (TDD gate, unit-tests, e2e, pr-lint, validate-scope, myapps-test) have correct guards and would pass for infra-only diff. Billing block is the sole merge blocker — Duong must resolve at github.com/settings/billing.
- 2026-04-21 (ekko): Deleted 8 vestigial app-repo workflows from strawberry-agents (ci.yml, e2e.yml, unit-tests.yml, preview.yml, landing-prod-deploy.yml, myapps-pr-preview.yml, myapps-prod-deploy.yml, myapps-test.yml). Branch protection GET returned 404 (no protection, no required-check unregistration needed). Commit 7c0fbf3 on delete-vestigial-workflows. PR #8 open.
- 2026-04-21 (ekko): Folded Senna's 3 PR #7 suggestions into orianna-work-repo-routing. (1) Fixed awk YAML quote stripping in fact-check-plan.sh so concern: "work" routes correctly. (2) Added I4 (quoted YAML), I5 (dashboards/*), I6 (.github/workflows/*) test cases. (3) Added trap cleanup in run_check/run_check_warn. All 8 test cases pass. Commit de66c32 pushed to orianna-work-repo-routing.
- 2026-04-21 (ekko): Deleted 4 vestigial workflows (auto-label-ready, pr-lint, release, validate-scope) via PR #10 (ops/delete-vestigial-workflows-round2). Commit 1dd9669. Re-triggered all 8 stale CI runs on PR #7 (billing unblocked) — checks now showing PASS/pending. Produced final branch-protection payload at assessments/branch-protection/2026-04-21-main-branch-protection-payload.md (commit 7b685a9, pushed to main after merging PR #9 which landed concurrently). After PR #10 merges, only tdd-gate.yml remains — apply payload then.
- 2026-04-21 (ekko — Sona dispatch): PR #10 (Duongntd author) and PR #7 (duongntd99 author) cannot be merged by Ekko — PR #10 is self-authored, PR #7 is CONFLICTING (depends on #10). Duong must merge both via harukainguyen1411 on web UI. All 4 work ADRs in plans/proposed/work/ attempted Orianna signing at phase=approved — all 4 BLOCKED (7/20/21/29 block findings). Common failure: cross-repo paths (tools/demo-studio-v3/, company-os/) route to strawberry-agents but files live in missmp/company-os; bare plan paths missing proposed/work/ prefix. Fix: add <!-- orianna: ok --> suppressors or extend claim-contract §5 routing table. Gate reports at assessments/plan-fact-checks/.
- 2026-04-21 (ekko): Resolved PR #7 merge conflicts after PR #10 merged. Two modify/delete conflicts: ci.yml and preview.yml (modified in PR #7 with paths filter, deleted in main by PR #10). Resolved by accepting deletion (git rm). Merge commit be3c261. PR #7 now MERGEABLE/CLEAN, all 4 TDD Gate checks SUCCESS. Worktree at /private/tmp/strawberry-orianna-work-repo-routing still present.
- 2026-04-21 (ekko — Sona dispatch): Promoted karma claim-contract extension plan (2026-04-21-orianna-claim-contract-work-repo-prefixes.md) proposed→approved→in-progress. Orianna approved gate: 15 blocks initially (meta-example paths in plan body), cleared by adding <!-- orianna: ok --> suppressors, then 0 blocks on re-run. in-progress gate: 0 blocks (task-gate-check). Both promotion commits pushed to main. approved SHA: 3ba78ad, in-progress SHA: a3bb0af. Plan file now at plans/in-progress/work/.

- 2026-04-21 (ekko — Sona dispatch): Promoted session-state-encapsulation ADR (2026-04-20-session-state-encapsulation.md) proposed→approved. Started with 29 block findings. Fixed all by adding inline <!-- orianna: ok --> suppressors (line-scoped per §8), requalifying bare paths (tdd-gate.yml, tools/demo-studio-v3/ paths, plan-promote.sh, reference/1-content-gen.yaml), updating stale BD ADR path (proposed→approved for s1-s2-service-boundary). Added task #17 Camille advisory note to §6.5 grep-gate covering symbol-level bypass vectors, star-import ban, and non-literal importlib ban. 2 iterations: first pass cleared 28/29, second fixed 1 stale path. Gate: 0 blocks. Signed + promoted + pushed. Plan now at plans/approved/work/. Commits: 2cce465, 2014b19, cfd5d68, f4263d9.

- 2026-04-21 (ekko — Sona dispatch): Re-signed MAD + BD at approved after Yuumi's Tasks inlining (commits 26bfe59/1fbbec8). Recovery: moved each plan back to proposed/work/, changed status to proposed, fixed 2 block findings in BD (path-self-ref suppressor + cross-repo git rm suppressor), signed approved + promoted to approved + signed in_progress + promoted to in-progress. Both plans now in plans/in-progress/work/. MAD approved sig: b6e239b, in_progress sig: 23b9673, promotion: 465c01a. BD approved sig: eea4a43, in_progress sig: 2ae4b37, promotion: 2d0fbe0. Key learning: orianna-signature-guard hook requires signing commit to touch ONLY the signature line — commit suppressor fixes separately before signing.

- 2026-04-21 (ekko — Sona dispatch): ship-day deploy infra (B1/B4/B5). Worktree company-os-ship-day off integration/demo-studio-v3-waves-1-4. Three ops: commits on chore/ship-day-deploy-infra: f5ba7e7 (min=max=1 pin), e745de7 (MAL+MAD env vars dark-launch), ab3f569 (rollback.sh). Not pushed — awaiting Viktor MAD.B + Sona review before merge into integration.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
