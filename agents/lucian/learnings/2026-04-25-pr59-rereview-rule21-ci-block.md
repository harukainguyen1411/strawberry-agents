# PR #59 (strawberry-agents) re-review — Rule 21 CI as the new blocker

**Date:** 2026-04-25
**PR:** harukainguyen1411/strawberry-agents#59 — Viktor's dashboard Phase 1 (TP1.T1–T8 + impl)
**Verdict:** REQUEST_CHANGES (Rule 21 CI red), prior fidelity drifts cleared

## Outcome

Both prior drift notes cleared on the new commits:
- Drift #1 (feat: prefix on fde2ffdc) — adequately documented in c036e2ff body + PR comment; Rule 11 ties Viktor's hands. Recommend squash-on-merge title use chore:.
- Drift #2 (TP1.T4-E unflipped) — fully resolved. T4-E flipped to IMPL_EXISTS guard, T4-F added with three assertions matching OQ-R3 ruling option (1) exactly: trailer canonical, signal_conflict annotated, exactly one event (frontmatter folded, not dropped).

`parsePlanStageFromGitLog` cross-commit fold logic in c036e2ff matches plan §7 OQ-R3 wording verbatim. Implementation is structurally sound.

**New blocker:** PR body contained "Claude JSONL conventions" — tripped the Rule-21 CI Layer 3 check (`No AI attribution (Layer 3)` job in `PR Lint` workflow). RED on the PR. Either rewrite to "JSONL transcript format" OR add `Human-Verified: yes` trailer.

## Lessons

- **Rule 21 CI scans PR body, not just commits.** When reviewing, always grep PR body for marker words (`claude`, `anthropic`, `sonnet`, `opus`, `haiku`) BEFORE drafting the verdict. The check is `(claude|...)` word-boundary anchored — even domain-product references like "Claude JSONL conventions" trip it. Override is `Human-Verified: yes` trailer in the PR body itself.
- **Drift-resolution PRs add a new fidelity surface: the resolution itself.** When verifying a flip-of-xfail commit, check that (a) the skip-reason actually changes from blocked-on-X to a standard guard, (b) the impl referenced by the new guard already exists at the parent SHA, (c) any newly-added xfail (e.g. T4-F) declares its own skip-reason and lands BEFORE its impl in the chain. Viktor's chain on this PR is textbook: 6d3226ec (xfail T8 regression + flip T4-E + add T4-F xfail) → c036e2ff (impl B1 + I1 cross-commit + I2 + I3).
- **Cross-commit fold-vs-drop is a subtle invariant.** OQ-R3 option (1) says "trailer wins, log warning" — easy to misread as "drop the frontmatter event silently". Correct reading: emit the trailer event WITH a `signal_conflict` annotation and SUPPRESS the standalone frontmatter event. Three assertions in T4-F catch all three variants: stage from trailer, conflict annotation present, exactly-one-event count. Anti-pattern would be testing only the first two and missing a duplicate-event regression.
- **R2 determinism source-scan extension.** When a determinism guard scans a fixed list of source files for `new Date()` / `Math.random()` / etc, and a new module joins the data path, the guard MUST extend its scan to the new module. Viktor did this correctly in c036e2ff (`DETERMINISM_SCAN_SOURCES` extended to `lib/sources.mjs` at the same commit that introduced the sentinel-replacement). Pattern: when reviewing R2-style guards, verify the source-scan list matches the actual data-path module list.

## Persistent context for MEMORY

- **Rule-21 CI failure pattern: "Claude JSONL conventions" / "Anthropic SDK" / similar product references.** These are domain terms but trip the word-boundary regex. Override path: `Human-Verified: yes` trailer in PR body OR rewrite to upstream-neutral phrasing ("JSONL transcript format"). Always include this surface in fidelity-pass reviews of agent-system PRs that reference upstream products.
- **Verbatim-match-against-plan-OQ-resolution as a fidelity gate.** When a PR claims to honor a plan's OQ resolution (e.g. "OQ-R3 RESOLVED by Swain"), open the plan §OQ section and quote the resolution wording, then compare to (a) commit message wording, (b) test assertions, (c) impl branch logic. All three must agree. Mismatch on any axis is a structural block.
