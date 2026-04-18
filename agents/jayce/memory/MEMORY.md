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

## Sessions
- 2026-04-18: Assigned B16 (task #8); B16a worktree created, recon surfaced PR #141 supersession path; stood down on GitHub Actions billing block before any commit/push.
- 2026-04-18 (session 2): D2 POST /api/runs (PR #177) + D1 report-run.sh fixes (PR #169) + B3 signed-urls CI fixes (PR #154). All three PRs pushed; awaiting Jhin/Azir review + Duong merge.
- 2026-04-18 (session 3): PR #177 D2 review cycle complete — fixed batch cap guard (1+cases+2×artifacts>500), resolved main merge conflicts. PR pushed at 5358722, conflict-free, pending Duong merge.
- 2026-04-18 (session 4): D1 bats xfail flip + it.failing→it.fails fix on health/firestore xfail files + stripped client-side case IDs. PR #169 updated (b15516d), chore/d1-report-run ready for review.
- 2026-04-19: Orianna O3.1-O3.4 — built fact-check gate scripts and plan-promote integration. O1.1 (.claude/agents/orianna.md) blocked by write-permission guard; Duong needs to create that file manually.
- 2026-04-18 (O6 bugs): Fixed three bugs Vi caught in O6 smoke testing — invalid claude CLI flags in orianna-fact-check.sh + orianna-memory-audit.sh; brace-expansion false positives in fact-check-plan.sh.
- 2026-04-18 (Bug-A Bug-B): Fixed report picker prefix collision ([0-9]* glob) and implemented orianna:ok suppression syntax. PR #183 pushed, awaiting review.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
