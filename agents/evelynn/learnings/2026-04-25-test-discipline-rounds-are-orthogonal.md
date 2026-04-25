# Test-discipline review rounds are orthogonal to functional correctness

**Date:** 2026-04-25
**Source:** PR #59 dashboard Phase 1 — four review cycles, two full CHANGES_REQUESTED rounds from Senna

## Observation

PR #59 required four review iterations. The first CHANGES_REQUESTED batch (B1/I1/I2/I3 + nits) was about functional correctness and naming. After those resolved, Senna's second CHANGES_REQUESTED batch surfaced three entirely new blockers that were specifically test-discipline failures: tests that over-asserted on implementation detail, tests that didn't exercise the code path they claimed to test, and tests missing edge-case coverage. These are structurally independent of functional correctness — a test suite can be correct and complete about happy-path behavior while still being discipline-deficient.

## Generalizable lesson

Test-discipline failures form their own review category, separate from functional correctness and plan fidelity. They tend to surface only after functional issues are resolved, because reviewers prioritize behavioral blockers first. Expecting a single review pass for a complex impl PR is optimistic; budget two passes minimum when the PR includes significant new test coverage.

When Senna returns CHANGES_REQUESTED twice on the same PR, do not interpret the second round as scope creep or reviewer over-reach. It means the first pass resolved one dimension and the second pass is examining a different dimension. The right response is to address the second batch as thoroughly as the first — not to expedite or push back.

## Action implication

Before dispatching Viktor on complex-lane PRs, brief Rakan explicitly on test-discipline expectations (not just xfail structure) in the delegation prompt. Rakan writing 59 structurally-sound xfails does not guarantee discipline-sound test patterns — those are the implementer's responsibility after the xfails pass.

**Last used:** 2026-04-25
