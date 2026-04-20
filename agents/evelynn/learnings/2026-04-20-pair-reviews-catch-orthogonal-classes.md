# Pair reviews catch orthogonal defect classes

**Date:** 2026-04-20
**Source:** PR #6 (Plan-Structure Pre-Lint), Senna + Lucian dual review

## Observation

Senna (code quality + security) and Lucian (plan/ADR fidelity) reviewed the same PR and raised different, non-overlapping blocking issues. The Senna block did not anticipate the Lucian block and vice versa. Both were load-bearing.

## Lesson

Dual review with role-differentiated reviewers is not redundant. The two reviewers examine the diff through different lenses — one asks "is this safe and correct?" while the other asks "does this match the intent in the plan?" A clean Senna pass gives no signal about Lucian's concerns, and vice versa. Treat them as independent gates, not checkboxes.

## Generalization

Whenever two reviewers appear to duplicate coverage, verify they are examining the artifact through genuinely different lenses. If they are, both are non-redundant. Only collapse reviewers when their classification criteria fully overlap.

| last_used: 2026-04-20 |
