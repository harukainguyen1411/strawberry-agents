---
status: proposed
concern: personal
owner: karma
created: 2026-04-20
orianna_gate_version: 2
tests_required: true
tags: [orianna, hooks, plan-lifecycle, shift-left]
related:
  - plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md
  - architecture/plan-lifecycle.md
orianna_signature_approved: "sha256:5399af90ddec04acd6be5d7a1d4d4cdf6ec1a035313542fdd2214e1cfa0c8253:2026-04-20T16:07:41Z"
---

# Plan-structure pre-lint (shift Orianna's deterministic checks left)

## 1. Problem & motivation

Orianna's structural plan checks (required frontmatter, `estimate_minutes:` on every task, `## Test plan` presence when `tests_required: true`) are deterministic and currently only run at promotion-time via the LLM fact-check path. That is expensive and late: a planner can commit a structurally broken plan, push, and only find out when `scripts/plan-promote.sh` invokes Orianna. These checks are pure string/AWK operations — they should fail at `git commit`, not at promote.

Two shifts:
1. A **plan template** (`plans/_template.md`) gives planners a correct-by-construction starting point. Reduces "blank file → missing frontmatter" errors.
2. A **pre-commit structural linter** (`scripts/hooks/pre-commit-plan-structure.sh`) runs the same deterministic checks Orianna runs, on any staged `plans/**/*.md`. Sub-second, no LLM. Same error messages as Orianna so the feedback is consistent.

The structural check logic currently lives partly in `scripts/_lib_orianna_estimates.sh` and partly inside Orianna's prompt. To avoid drift, we extract all deterministic structural checks into `scripts/_lib_plan_structure.sh` — single source of truth that both the hook and Orianna's wrapper can source.

## 2. Decision

Ship all three in one pass (quick-lane):
- Factor deterministic structural checks out of `scripts/_lib_orianna_estimates.sh` (and any checks currently only in Orianna's prompt) into new `scripts/_lib_plan_structure.sh`. Existing callers in `scripts/orianna-fact-check.sh` / `scripts/fact-check-plan.sh` keep working by re-sourcing through the new lib.
- Author `plans/_template.md` with stubbed frontmatter + required section skeletons. This plan file IS written to that template as the dogfooding test.
- Add `scripts/hooks/pre-commit-plan-structure.sh`. Wire via `scripts/install-hooks.sh`. TDD: xfail test committed before implementation (Rule 12).

### Scope — out

- No standalone `scripts/lint-plan.sh` (hook is the UX).
- No new CI workflow (pre-commit + existing Orianna gate are sufficient).
- No MCP tooling.
- No LLM-dependent checks in the hook — those remain Orianna's job at promotion.

## 3. Design

### `scripts/_lib_plan_structure.sh` (new, sourced-only)

Public functions:

- `check_plan_frontmatter <plan_file>` — Step A. Required keys: `status`, `concern`, `owner`, `created`, `orianna_gate_version`, `tests_required`. Optional: `tags`, `related`. Returns non-zero with `[lib-plan-structure] BLOCK: ...` on any missing key. Message format matches existing Orianna prompt wording.
- `check_task_estimates <plan_file>` — Step B. Delegates to existing `check_estimate_minutes` from `_lib_orianna_estimates.sh` (source it internally). No logic duplication.
- `check_test_plan_present <plan_file>` — Step D. If `tests_required: true` (or field absent — default true), require a `## Test plan` heading followed by at least one non-blank, non-heading line before the next `## ` heading or EOF.
- `check_plan_structure <plan_file>` — orchestrator. Runs A, B, D in order; returns 0 only if all pass; aggregates stderr.

No shebang; file is sourced-only (same pattern as `_lib_orianna_estimates.sh`).

### `plans/_template.md` (new)

Literal content — planners copy and fill. Uses `<placeholder>` style so it fails pre-lint until filled in (good — forces conscious fill). Section headings match what the linter requires.

### `scripts/hooks/pre-commit-plan-structure.sh` (new)

Behavior:
1. `git diff --cached --name-only --diff-filter=ACM` → filter to `plans/**/*.md`.
2. Skip `plans/_template.md` itself (it has placeholders by design).
3. Skip files under `plans/archived/**` (grandfathered).
4. For each remaining staged plan: source `scripts/_lib_plan_structure.sh` and call `check_plan_structure`. Accumulate failures.
5. Exit 0 if all pass, 1 on any BLOCK. Print actionable errors to stderr.

Must be POSIX bash (Rule 10). Sub-second on 10+ staged plans.

### `scripts/install-hooks.sh` wiring

Append invocation of `pre-commit-plan-structure.sh` to the composed pre-commit hook, ordered AFTER secrets-guard (secrets always win) and BEFORE unit-tests (cheapest first).

### `architecture/plan-lifecycle.md` doc update

Short section: "Pre-commit structural lint — what it checks, what it doesn't, how it relates to Orianna's promotion-time LLM check. Template entry point: `plans/_template.md`."

## 4. Non-goals

- Reformatting existing plans that happen to fail the new checks. Hook only runs on staged diffs; retro-fix is out of scope.
- Changing Orianna's LLM prompt. Orianna continues running the full (structural + semantic) check at promote; the pre-commit is a fast-path subset, not a replacement.

## 5. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Hook false-positives block legitimate commits | Template dogfooding (this plan); `plans/archived/**` excluded; template file excluded |
| Drift between `_lib_plan_structure.sh` and Orianna prompt | T1 explicitly extracts the single source; Orianna prompt references the lib's rule numbers |
| Pre-commit slowdown | Pure awk/grep; benchmarked in T5 acceptance (< 200ms for 10 plans) |

## 6. Tasks

- [ ] **T1** — Extract structural checks into `scripts/_lib_plan_structure.sh`. estimate_minutes: 25. Files: `scripts/_lib_plan_structure.sh` (new), `scripts/_lib_orianna_estimates.sh` (no change — source from new lib), `scripts/orianna-fact-check.sh` (verify still green). DoD: `check_plan_frontmatter`, `check_task_estimates`, `check_test_plan_present`, `check_plan_structure` all implemented; `scripts/test-orianna-estimates.sh` still passes; new functions exercised by a smoke driver.
- [ ] **T2** — Author `plans/_template.md`. estimate_minutes: 15. Files: `plans/_template.md` (new). DoD: contains all required frontmatter keys with `<placeholder>` values; contains `## 1. Problem & motivation`, `## 2. Decision`, `## 6. Tasks`, `## Test plan`, `## Rollback`, `## Open questions` headings; tasks section has one example task entry with `estimate_minutes: <1-60>` placeholder; pre-commit hook explicitly skips this path.
- [ ] **T3** — Write xfail test then implement `scripts/hooks/pre-commit-plan-structure.sh`. estimate_minutes: 45. Files: `scripts/hooks/test-pre-commit-plan-structure.sh` (new — xfail first, committed as its own commit per Rule 12), `scripts/hooks/pre-commit-plan-structure.sh` (new). DoD: xfail test committed before impl on same branch; test covers (a) clean plan passes, (b) missing frontmatter key fails with specific message, (c) task missing `estimate_minutes:` fails, (d) banned literal `(d)` fails, (e) `tests_required: true` + missing `## Test plan` fails, (f) `plans/_template.md` is skipped, (g) `plans/archived/**` is skipped. POSIX bash. Runs in < 200ms for 10 staged plans.
- [ ] **T4** — Wire hook into `scripts/install-hooks.sh`. estimate_minutes: 10. Files: `scripts/install-hooks.sh`. DoD: composed pre-commit runs the new hook after secrets-guard, before unit-tests; re-running `install-hooks.sh` is idempotent; `scripts/hooks/test-hooks.sh` still green.
- [ ] **T5** — Smoke test on known-good + synthetic-broken plans. estimate_minutes: 20. Files: none committed (smoke only). DoD: (a) this plan file passes (dogfood); (b) synthetic plan with 3 seeded defects produces exactly 3 BLOCK messages; (c) runtime measured on 10 staged plans < 200ms; results captured in commit message of T3.
- [ ] **T6** — Document in `architecture/plan-lifecycle.md`. estimate_minutes: 15. Files: `architecture/plan-lifecycle.md`. DoD: new subsection titled "Pre-commit structural lint"; links to `scripts/hooks/pre-commit-plan-structure.sh`, `scripts/_lib_plan_structure.sh`, `plans/_template.md`; states the shift-left rationale and the split of responsibilities with Orianna's promotion-time gate.

Total estimate: 130 minutes.

## Test plan

The xfail test `scripts/hooks/test-pre-commit-plan-structure.sh` (committed first per Rule 12) is the regression contract. It protects these invariants:

- **Frontmatter invariant** — A plan missing any required key (`status`, `concern`, `owner`, `created`, `orianna_gate_version`, `tests_required`) is blocked at commit time.
- **Estimate invariant** — Every `- [ ]` / `- [x]` task entry under `## Tasks` / `## 6. Tasks` carries an integer `estimate_minutes:` value in `[1, 60]`. Banned literals (`(d)`, `(h)`, `hours`, `days`, `weeks`) are rejected. (Delegated to existing `check_estimate_minutes`; test confirms delegation still works through the new lib.)
- **Test-plan invariant** — When `tests_required: true`, a non-empty `## Test plan` section exists.
- **Scope invariants** — `plans/_template.md` is skipped (placeholder values tolerated); `plans/archived/**` is skipped; non-`plans/**/*.md` files are ignored; untouched staged plans are not re-checked.
- **Parity invariant** — Running the new lib's `check_plan_structure` on a plan that passes Orianna's LLM structural checks must also pass, and vice versa on clean cases. Dogfooding acceptance: this plan (`plans/proposed/personal/2026-04-20-plan-structure-prelint.md`) passes both the new hook and `scripts/orianna-fact-check.sh`.

Test harness lives alongside existing hook tests (`scripts/hooks/test-*.sh`). Invoked by `scripts/hooks/test-hooks.sh`. Pre-push TDD gate enforces xfail-before-impl on the branch.

## Rollback

Low-risk, fully local:
1. Revert the commits for T1–T6 (merge, not rebase — Rule 11).
2. Re-run `scripts/install-hooks.sh` to regenerate the composed pre-commit without the new step.
3. `plans/_template.md` can be left in place (harmless) or deleted.

No data migration, no schema change, no external integration. No remote side-effects.

## Open questions

- **OQ1** — Should `plans/proposed/**` grandfather existing plans that would fail the new checks? Current recommendation: no retro-fix; the hook only runs on staged diffs, so pre-existing plans are unaffected until next edit. Resolve during T3 review if CI starts re-checking.
- **OQ2** — Does Orianna's promotion-time gate need to know the pre-commit already ran (to skip duplicate work)? Current recommendation: no — Orianna re-runs everything as the authoritative gate; duplicate ~50ms is acceptable. Flag if promotion latency becomes a concern.
