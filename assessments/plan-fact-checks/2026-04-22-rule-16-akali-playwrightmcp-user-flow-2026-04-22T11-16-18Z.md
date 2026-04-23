---
plan: plans/approved/personal/2026-04-22-rule-16-akali-playwrightmcp-user-flow.md
checked_at: 2026-04-22T11:16:18Z
auditor: orianna
check_version: 2
gate: task-gate-check
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 0
---

## Block findings

1. **Step B — Test tasks:** no test task found in `## Tasks`. Task kinds are `docs`, `docs`, `docs`, `impl`, `docs` (T1–T5); no task has `kind: test` and no task title matches `^(write|add|create|update) .* test` (case-insensitive). The xfail tests described in `## Test plan` (T1–T4 test cases) are prose descriptions inside the test plan, not entries in the `## Tasks` section. `tests_required: true` is declared in frontmatter, so at least one qualifying task is required per §D2.2. | **Severity:** block

Suggested fix: add a task such as **T0. Write xfail pr-lint-check tests** with `kind: test` (or retitle an existing task) to the `## Tasks` section, covering the fixture scaffolding in `scripts/hooks/tests/pr-lint/` and the extraction of `scripts/ci/pr-lint-check.sh` that T4 depends on. This also aligns with the Rule 12 xfail-first invariant referenced throughout the plan.

## Warn findings

None.

## Info findings

None.

## Notes (non-blocking)

- Step A: `## Tasks` section present with 5 entries (T1–T5). ✓
- Step C: `## Test plan` section present and non-empty (describes 4 test cases T1–T4 plus invariants list). ✓
- Step D: Sibling-file grep returned no results for `-tasks.md` or `-tests.md`. ✓
- Step E: `orianna_signature_approved` present and verified valid via `scripts/orianna-verify-signature.sh` (hash=38524bb8…4ae896, commit=ffba008b). ✓
