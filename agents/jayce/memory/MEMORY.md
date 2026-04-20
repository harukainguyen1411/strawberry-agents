# jayce Memory

- [2026-04-17 B8 vite 7 bump](../learnings/2026-04-17-b8-vite7-direct-bump.md) — workspace lockfile conflict resolution, plugin-vue compat, test mock patterns, alert scope (direct vs transitive)
- [2026-04-18 D2 POST /api/runs](../learnings/2026-04-18-d2-post-runs-xfail-vitest-mocking.md) — it.failing→it.fails fix, INGEST_TOKEN env pattern for middleware tests, cross-worktree dep bundling
- [2026-04-18 B16a PR supersession recon](../learnings/2026-04-18-b16a-pr-supersession-recon.md) — check alert manifest_path + current main state before rebasing stale dependabot PRs
- [2026-04-18 Rule-3 raw-worktree precedent](../learnings/2026-04-18-raw-worktree-add-rule3-precedent.md) — raw `git worktree add` OK with team-lead authorization; wrapper guard is convenience, rule 1 is the invariant
- [2026-04-18 unit-tests workflow npm install](../learnings/2026-04-18-unit-tests-workflow-npm-install.md) — missing npm install in CI workflow; CWD-relative require fix; first-PR latent bug pattern
- [2026-04-18 D1 reporter normalizer](../learnings/2026-04-18-d1-report-run-normalizer.md) — check for prior work before implementing; it.fails not it.failing; strip client-side IDs for server-owned entities; inline env overrides in bats

- [2026-04-19 Orianna O3.1-O3.4](../learnings/2026-04-19-orianna-fact-check-gate.md) — LLM wrapper + bash fallback + plan-promote integration + pinned prompt; .claude/agents/ is write-protected; realpath --relative-to fails on macOS; glob/template filtering critical for bash fallback
- [2026-04-18 O6 smoke bug fixes](../learnings/2026-04-18-o6-smoke-bug-fixes.md) — correct claude CLI flags: --non-interactive→-p, --system→--system-prompt, --subagent→--agent, --prompt removed (positional); brace-expansion filter added to fact-check-plan.sh
- [2026-04-18 Orianna gate Bug-A and Bug-B](../learnings/2026-04-18-orianna-gate-bug-a-b.md) — Bug-A: [0-9]* anchor in report picker glob prevents prefix-collision with plan variants; Bug-B: orianna:ok suppression implemented in awk extract_tokens + LLM prompt + claim-contract.md §8

- [2026-04-19 P1.2-C _lib.sh](../learnings/2026-04-19-p1-2-lib-sh-implementation.md) — repo-root detection heuristic via decrypt.sh on PATH; comment text triggers static scanners; safe-to-source discipline; no cipher-existence check in dl_decrypt_env

- [2026-04-19 T5-T6 refresh-server + sbu](../learnings/2026-04-19-t5-t6-refresh-server-sbu.md) — await-in-non-async parse error; staggered test ports; PID guard pattern; branch off origin/main explicitly

- [2026-04-19 TD.1 vitest-reporter-tests-dashboard](../learnings/2026-04-19-td1-vitest-reporter-tests-dashboard.md) — new packages/* workspace pattern; xfail/xpassed Vitest result.note; atomic write; Firebase PR Preview failure is pre-existing/non-required

## Sessions
- 2026-04-18: Assigned B16 (task #8); B16a worktree created, recon surfaced PR #141 supersession path; stood down on GitHub Actions billing block before any commit/push.
- 2026-04-18 (session 2): D2 POST /api/runs (PR #177) + D1 report-run.sh fixes (PR #169) + B3 signed-urls CI fixes (PR #154). All three PRs pushed; awaiting Jhin/Azir review + Duong merge.
- 2026-04-18 (session 3): PR #177 D2 review cycle complete — fixed batch cap guard (1+cases+2×artifacts>500), resolved main merge conflicts. PR pushed at 5358722, conflict-free, pending Duong merge.
- 2026-04-18 (session 4): D1 bats xfail flip + it.failing→it.fails fix on health/firestore xfail files + stripped client-side case IDs. PR #169 updated (b15516d), chore/d1-report-run ready for review.
- 2026-04-19: Orianna O3.1-O3.4 — built fact-check gate scripts and plan-promote integration. O1.1 (.claude/agents/orianna.md) blocked by write-permission guard; Duong needs to create that file manually.
- 2026-04-18 (O6 bugs): Fixed three bugs Vi caught in O6 smoke testing — invalid claude CLI flags in orianna-fact-check.sh + orianna-memory-audit.sh; brace-expansion false positives in fact-check-plan.sh.
- 2026-04-18 (Bug-A Bug-B): Fixed report picker prefix collision ([0-9]* glob) and implemented orianna:ok suppression syntax. PR #183 pushed, awaiting review.
- 2026-04-19 (P1.2-C): Implemented scripts/deploy/_lib.sh (7 helpers). 26/26 bats tests green on branch chore/p1-2-lib-sh-xfail, commit d52f1b9. PR creation deferred — Evelynn/Duong to open.
- 2026-04-19 (P1.2 review I1+I4): PR #25 REQUEST_CHANGES from Jhin. Pushed missing d52f1b9 (C1). Hardened DL_REPO_ROOT detection — BASH_SOURCE[0] now authoritative, command-v fallback only when basename==tools (I1). Added 2 new bats tests. Deleted deploy script from apps/myapps/functions/package.json (I4). 28/28 tests green. Remote tip: 20c8c27.
- 2026-04-19 (T5+T6): Built refresh-server.mjs (PR #35) and sbu.sh (PR #37) for strawberry-app. All 4 T5 tests + 3 T6 tests pass. Both PRs open against main, awaiting review.
- 2026-04-19 (PR #35+#37 review fixes): Addressed Jhin REQUEST_CHANGES on both PRs. PR #35: added isLocalOrigin guard to GET /health, in-flight 409 guard, activeChild kill on SIGTERM, regression test 5. PR #37: replaced bare `open` with open_url() (open→xdg-open→start fallback), added liveness check after nohup, added test 4 (symlink-farm PATH isolation). Resolved merge conflict on t6 branch (force-pushed remote). Both pushed.
- 2026-04-19 (TD.1): Built @strawberry/vitest-reporter-tests-dashboard package. xfail commit 1f98f19, impl commit 21f23f8. PR #49 open on strawberry-app. All substantive CI checks pass.
- 2026-04-19 (TD.1 fix): Fixed nodeIdOf operator precedence bug (Jhin finding #2). Regression test bba5e62 + fix c63ddf7 pushed to chore/td1-vitest-reporter-tests-dashboard. PR #49 comment posted. Findings #1+#3 deferred to TD.2.
- 2026-04-19 (PR #34 snapshot id fix): Fixed `id: d.data()` bug in `portfolio_get_snapshot`. xfail commit 59ecbf9, fix commit 468e01d, pushed to feature/portfolio-v0-V0.4-portfolio-tools. PR comment posted. Not merged (Rule 18).
- 2026-04-19 (kill-auto-rebase): Deleted .github/workflows/auto-rebase.yml. PR #51 on harukainguyen1411/strawberry-app open, awaiting review. Branch: chore/kill-auto-rebase-cascade, commit a301e95.
- 2026-04-19 (P1.4 merge conflict): Resolved PR #26 merge conflicts. Only 1 of 5 listed files needed manual resolution (router/index.ts — formatting only). All 4 P1.4 vitest tests pass. Merge commit 8631802 pushed; PR now MERGEABLE.
- 2026-04-19 (PR #48 Lucian fix): Reverted paths-ignore on e2e.yml; added internal myapps-only gate (only_myapps output + early-exit step). PR body updated. Commit 1b7e38f on chore/e2e-scope-myapps. Awaiting Senna + Lucian re-review.
- 2026-04-19 (PR #32 V0.2 lint+gate fix): Fixed bare ternary lint errors in read-tracker + task-list routers. Restored VITE_E2E bypass in firebase/config.ts. Hardened myapps src/router/index.ts to short-circuit on non-auth routes and already-authenticated (local-mode) users. Commit 71cad12 pushed. PR comment posted.
- 2026-04-19 (router forward-ref fix PRs #32/#43/#44/#45): Removed forward-ref routes from V0.2 (CsvImport), V0.9, V0.10, V0.11 (auth/SignInCallbackView). Fixed secondary TS errors in V0.9+V0.11: useAuth named→default import, unused imports, props variable, t212.ts received type. All 4 branches build green and pushed. SHAs: V0.2=0217c4a, V0.9=381bd0e, V0.10=53bfe2a, V0.11=40399a4.

- 2026-04-19 (V0.10 Senna fixes): Fixed PR #44 critical findings — SignInView fake-success, Firestore hasOnly, useAuth dead flag. 4 fix commits (b055d02, bf6ff70, ef48fca, f7a5bec) + merge 941c50f. Pushed. PR comment posted.
- 2026-04-19 (V0.10 merge conflict): Resolved PR #44 DIRTY state. 1 conflict in router/index.ts — kept HEAD (V0.10). Merge commit ab7393b pushed. PR comment posted. Not merged (Rule 18).
- 2026-04-19 (V0.7 Senna fixes): Fixed PR #41 findings #1+#2. Xfail commit (2ac6d4b) + fix short/cover (0416baf) + fix asset-category (1239d27). 38/38 tests green. PR comment posted. Not merged (Rule 18).
- 2026-04-19 (V0.8 Senna fixes): Merged origin/V0.7 into V0.8 (clean, ort). Xfail 410e5e1 (strict Firestore mock, id: undefined regression). Fix 169ccb6 (destructure id out, add B.2.13 T212 EUR). 52/52 tests pass. PR #42 comment posted. Not merged (Rule 18).
- 2026-04-19 (PR #40 V0.6 Senna fixes): Fixed EU comma-decimal parsing (parseDecimal helper) + phantom BUY classifier (TRADE_ACTIONS allowlist). 3 commits: 960651b (xfail) + f8c01d8 (EU decimal) + 9ab8809 (phantom BUY). Pushed + commented on PR. Not merged (Rule 18).
- 2026-04-19 (PR #42 V0.8 main merge conflict): Resolved CONFLICTING state. 1 conflict in t212.ts — accountCurrency capture before TRADE_ACTIONS skip. index.ts auto-merged. Merge commit 18d0563. PR now MERGEABLE. Fast CI checks green; build/unit/E2E queued.

- [2026-04-20 Channels plugin + Node strip-types](../learnings/2026-04-20-channels-plugin-node-strip-types.md) — Node --experimental-strip-types replaces Bun; .ts import paths required; plugin cwd != repo root (use git rev-parse); --channels server:name vs plugin:name@marketplace; --plugin-dir needed alongside --channels

## Sessions
- 2026-04-20: Built strawberry-inbox Channels plugin + /check-inbox skill. Pushed directly to main (infra, not app code). Plan promoted to implemented.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
