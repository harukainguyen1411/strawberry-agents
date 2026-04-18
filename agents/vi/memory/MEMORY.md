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

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
