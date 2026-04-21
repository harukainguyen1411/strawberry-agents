# PR #13 — memory-consolidation redesign fidelity review

**Date:** 2026-04-21
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/13
**Plan:** `plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md`
**Verdict:** APPROVE with 3 drift notes (follow-up required)

## Key pattern — xfail-first test bugs across task boundaries

When a plan splits xfail-first test authorship (Rakan owns xfail skeletons T1/T3/T5) from implementation (Viktor owns T2/T4/T6/T7), test-design bugs in the skeletons surface at the impl commits and show up as "failures" in the PR body — even though production code is correct.

Examples from PR #13:
- **A4 (test-memory-consolidate-index.sh):** `write_prose_shard` helper writes to shared `$LAST` fixture before A4 overrides, leaking prose into A7's idempotency-baseline fixture.
- **B2 (test-memory-consolidate-archive-policy.sh):** offset math makes shard index 25 the newest (position 1), but assertion checks archived UUIDs 0021–0025 which are positions 1–5 (newest 5). Should check UUIDs 0001–0005.

**Implication for Lucian:** when a PR body says "pre-existing failures, outside scope," trace the commit authorship. If the failure is in an xfail skeleton from an earlier task owned by a different author, it's legitimate test-design drift (not a production bug) but still violates the plan's DoD ("must pass"). Call it as a drift note + follow-up, not a block.

## What to verify on fidelity reviews of multi-task PRs

1. **Plan body untouched.** `git diff main <branch> -- plans/` should be empty when the plan is Orianna-signed at the current lifecycle state.
2. **Commit subjects match plan DoD.** Every `### T<N>` section has a "Commit subject" field; grep for exact string in `git log`.
3. **Rule 12 ordering.** Every impl commit must have its gating xfail commit on the same branch before it. Verify commit order.
4. **Hard invariants from ADR §7-style tables.** E.g., "positions 7+8 always last two entries" — grep the live agent-def file to confirm, not just the architecture doc.
5. **Re-run test suites on the branch tip.** Don't trust the PR body table; failures may be omitted (PR #13 omitted the archive-policy 9/10 from its table but surfaced it in the T4 commit body).

## Reviewer-auth reminder

Always preflight: `scripts/reviewer-auth.sh gh api user --jq .login` → must be `strawberry-reviewers`. Worked correctly this session.
