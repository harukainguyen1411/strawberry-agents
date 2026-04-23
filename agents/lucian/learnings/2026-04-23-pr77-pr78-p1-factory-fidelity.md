# PR #77 + #78 — P1 factory build chain fidelity (missmp/company-os)

Date: 2026-04-23
PRs: missmp/company-os#77 (T.P1.9), missmp/company-os#78 (T.P1.10a)
Plan: `plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md`
Verdict: APPROVE (advisory, via `duongntd99` plain comment — reviewer bot has no access to `missmp/*`)

## Key takeaways

- **`gh pr diff` 406s above 300 files; fall back to per-commit `gh api ...commits/<sha>`.** PR77's base is `main` but the branch carries ~80 cumulative commits from unrelated waves. Asking for the whole PR diff failed. Per-commit fetch via `gh api repos/.../commits/<sha>` with `.files[]` and `.patch` scoped cleanly to the T.P1.9 payload (2 files). Same trick works when a branch rebases on top of a long-lived feature root.
- **Rule 12 textbook across stacked PRs.** PR78 sits on top of PR77. Verified by checking `.parents[0]` of the impl SHA equals the xfail SHA, and `.parents[0]` of the xfail SHA equals PR77's head SHA. Cheap and deterministic; no need to read diffs to prove chain order.
- **Plan DoD with singular "the xfail" can be satisfied by multiple xfails.** T.P1.9 DoD says "xfail in test_factory_bridge_v2.py flips to pass" — the PR flipped 5 cases (the whole `TestP19TriggerFactoryV2PersistsRealIds` class). Not divergence; the plan's phrasing is loose. Approve and note the over-satisfaction is appropriate.
- **Cross-repo AI-trailer leakage.** PR77 commit `d8088bd` shipped with `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`. Strawberry cross-system rule bans this but the `missmp/company-os` repo has no commit-msg hook installed (hook lives in strawberry-agents). Drift note, not blocker. If Sona wants work-repo to enforce, the hook at `scripts/hooks/commit-msg-no-ai-coauthor.sh` would need to be portable-installed there.
- **Anonymity sign-off pattern for work-scope.** Both comments signed `-- reviewer`; no agent name, no `anthropic.com`, no `Co-Authored-By: Claude`. The reviewer-auth path wasn't usable (404), but the same anonymity discipline applies to plain `gh pr comment` under `duongntd99`.
