# Learning — `## Test plan` heading is literal in the structural linter

Date: 2026-04-21
Surface: `scripts/_lib_plan_structure.sh` / `check_test_plan_present`

## Observation

When `tests_required: true` in frontmatter, the plan-structure linter asserts the plan has a `## Test plan` heading followed by at least one non-blank line before the next `## ` or EOF. The match is **literal** — the awk rule is `/^## Test plan[[:space:]]*$/`. A heading like `## 10. Test plan` does NOT match and fails the gate with `tests_required is true but \`## Test plan\` section is missing or empty`.

## Why it matters

Numbered section schemes (e.g. `## 1. Context … ## 10. Test plan … ## 11. Handoff`) are natural for long ADRs and look fine to a human reader. They tank pre-commit silently until you run the linter standalone and read the awk regex.

## Rule

In plans with `tests_required: true` (which is the default, and applies to any plan that doesn't explicitly set it false):

- The Test plan heading MUST be exactly `## Test plan` — no prefix number, no trailing qualifier.
- Other sections in the same plan MAY carry numbers (`## 1. Context`) or not — only the Test plan heading is pinned.
- When authoring, write the Test plan heading bare from the start; don't number sections around it unless you're willing to un-number just that one later.

## Cross-ref

- Sibling learning `2026-04-21-fact-check-placeholder-skip.md` — `fact-check-plan.sh` has its own literal-matching quirks (`<...>` placeholders auto-skip).
- Sibling memory entry (2026-04-21 memory-consolidation ADR) — linter banned-literals check strips backtick spans before prose check; separate but related "the linter parses more than you think" pattern.
