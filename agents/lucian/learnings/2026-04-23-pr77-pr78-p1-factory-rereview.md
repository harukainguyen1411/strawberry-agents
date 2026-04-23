# PR #77 + #78 — P1 factory re-review after amendments

Date: 2026-04-23
PRs: missmp/company-os#77 (SHA 33c8003), #78 (SHA 28b58b5)
Plan: plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md (T.P1.9, T.P1.10a)
Verdict: APPROVE x2 (advisory via duongntd99 plain comment — reviewer bot has no access to missmp/*)

## Key takeaways

- **Single-commit diff fetch still the winning move on branches with 300+ cumulative commits.** `gh api repos/<o>/<r>/commits/<sha> --jq '.files[] | .patch'` scoped cleanly to the 3-file T.P1.9 payload and 2-file T.P1.10a fix. Faster than diffing the PR range.
- **Backward-compat read pattern for deprecated session fields matches §D5 exactly.** `session.get("buildId") or session.get("factoryRunId", "")` — new field preferred, old field fallback, both optional. Good template for future one-release deprecations.
- **"Read but dropped" category of Senna findings tends to be 1-line fixes with a mandatory regression test.** The failureReason fix on PR78 was the clean case: added the write, added a test that patches the in-memory store and asserts the exact key. Rule 13 satisfied in the same commit.
- **AI-coauthor trailer got scrubbed on PR77 amendment.** Confirms the first-pass drift note was actionable rather than structural. No work-repo commit-msg hook yet; the scrub was voluntary by the author. Cross-repo hook install still a live follow-up.
- **Rule 12 chain survives merge commits.** PR78 ordering was xfail(4a6d0fe) → impl(d9a147f) → base-merge(2745b35) → fix(28b58b5). The merge commit doesn't break the xfail-before-impl chain because the impl parent is the xfail, and the subsequent fix is a legitimate post-impl followup (not a new feature requiring its own xfail).
