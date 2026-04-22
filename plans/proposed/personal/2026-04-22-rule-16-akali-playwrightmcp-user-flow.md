---
status: proposed
concern: personal
complexity: quick
orianna_gate_version: 2
owner: Karma
created: 2026-04-22
tests_required: true
---

# Rule 16 strengthening — name Akali, require Playwright MCP, extend to user-flow changes

## Context

Duong's amendment: "if a change involve UI or user flow, we must do a QA step with Akali using playwrightMCP". Today's Rule 16 in repo-root `CLAUDE.md` (line 93) names only a generic "QA agent", says "Playwright" without specifying MCP, and scopes the trigger to "UI PRs". We need to (a) name **Akali** explicitly, (b) require the Playwright MCP tooling (matching her actual `mcpServers` config in `.claude/agents/akali.md`), and (c) extend the trigger to **user-flow changes** — new routes, forms, state transitions, auth/session lifecycle — even when there is no visual delta.

The rule claims enforcement by a "PR body linter". Investigation shows the linter does **not** exist: `.github/workflows/` contains only `tdd-gate.yml`; the `QA-Report:` marker is mentioned in `.github/pull_request_template.md` and `.claude/agents/akali.md` but nothing validates it on PR events. We ship the linter as part of this plan (`.github/workflows/pr-lint.yml`) so the "enforced by" claim becomes true. <!-- orianna: ok — directory token .github/workflows/ would crash awk -->

No schema, no external integration, no cross-concern change. Single-concern docs + one new workflow + one template tweak. Quick lane appropriate.

## Tasks

### T1. Amend Rule 16 in repo-root `CLAUDE.md`

- kind: docs
- estimate_minutes: 10
- Files: `CLAUDE.md` (line 93 block).
- Detail: Replace the Rule 16 paragraph with wording that (1) names **Akali** explicitly and cross-references `.claude/agents/akali.md`, (2) requires the **Playwright MCP** tool family (`mcp__plugin_playwright_playwright__*`) rather than a local CLI, (3) broadens the trigger from "UI PR" to **"UI or user-flow PR"** with an inline glossary — user flow = new routes, new forms, state-transition changes, auth flows, session lifecycle, (4) preserves `assessments/qa-reports/` report location, `QA-Report:` PR body marker, PR body linter enforcement, and the non-UI / non-user-flow exemption. <!-- orianna: ok — assessments/qa-reports/ is a directory token -->
- DoD: Rule 16 text contains the literal tokens "Akali", "Playwright MCP", and "user flow"; the exemption clause still reads "Non-UI and non-user-flow PRs exempt"; no other numbered rule renumbered.

### T2. Restate Rule 16 in `architecture/pr-rules.md`

- kind: docs
- estimate_minutes: 8
- Files: `architecture/pr-rules.md`.
- Detail: Add a new `## QA Gate (Rule 16)` section after `## Review Team Protocol` that restates the amended rule in full and links back to repo-root `CLAUDE.md` rule 16 anchor plus `.claude/agents/akali.md`. Include the user-flow glossary.
- DoD: Section exists, matches Rule 16 wording in substance, references both source files by repo-relative path.

### T3. Align coordinator CLAUDE.md row wording

- kind: docs
- estimate_minutes: 5
- Files: `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`.
- Detail: In each agent-role table that names Akali, change the trigger column from "UI PR" to "UI or user-flow PR" and append "(Playwright MCP)" after her name. No other changes.
- DoD: Grep for "Akali" in both files shows the updated trigger token; no other table rows touched.

### T4. Ship the PR body linter

- kind: impl
- estimate_minutes: 35
- Files: `.github/workflows/pr-lint.yml` (new). <!-- orianna: ok — prospective file path -->
- Detail: Create a GitHub Actions workflow triggered on `pull_request` events (`opened`, `edited`, `synchronize`, `reopened`) that fetches the PR body via `gh pr view --json body` and runs a single bash check script (inlined in the workflow) to: (1) classify the PR as UI / user-flow / neither by scanning the PR's changed file paths (`gh pr diff --name-only`) against a UI path allowlist (`apps/*/app/**`, `apps/*/components/**`, `apps/*/pages/**`, `apps/*/routes/**`, `apps/*/forms/**`, `apps/*/auth/**`, `apps/*/session/**`) **and** by scanning the PR body for user-flow keywords (`new route`, `new form`, `state transition`, `auth flow`, `session lifecycle`, `user flow`); (2) if classified as UI or user-flow, require either `QA-Report:` or `QA-Waiver:` to be present in the body; (3) fail with a clear message referencing Rule 16 when missing. <!-- orianna: ok — glob patterns are prospective path examples, not real paths -->
- DoD: Workflow file parses (`yamllint` clean if available); bash script portion is POSIX-portable; failure message contains the literal string "Rule 16" and "Akali"; workflow does not fail when PR is pure docs/infra.

### T5. Update PR template QA row

- kind: docs
- estimate_minutes: 5
- Files: `.github/pull_request_template.md`.
- Detail: Tighten the `QA-Report` row comment to: "QA-Report: <path-or-url> | QA-Waiver: <reason> — required for any UI or user-flow PR (Rule 16); Akali via Playwright MCP. N/A only for non-UI, non-user-flow PRs."
- DoD: Row text matches above verbatim.

### T6. Write xfail pr-lint-check tests

- kind: test
- estimate_minutes: 20
- Files: `scripts/ci/pr-lint-check.sh` (new, extracted from T4 workflow), `scripts/hooks/tests/pr-lint/` (new dir with fixtures + runner). <!-- orianna: ok — prospective paths not yet created -->
- Detail: Extract the PR body linter bash script from T4's GitHub Actions workflow into a standalone `scripts/ci/pr-lint-check.sh` so it can be unit-tested locally. Create a POSIX shell test runner at `scripts/hooks/tests/pr-lint/run-tests.sh` with four fixtures matching the four test cases in `## Test plan`. Commit the tests as xfail (the linter check script exits non-zero before T4 ships the implementation; T4 then makes them green. <!-- orianna: ok — prospective fixture paths -->
- DoD: `scripts/ci/pr-lint-check.sh` exists and is POSIX-portable; test runner exits non-zero (xfail) before T4 lands; all four test cases are represented; test file committed on the implementation branch before any linter implementation. <!-- orianna: ok — prospective paths in DoD -->

## Test plan

Tests live in a new directory `scripts/hooks/tests/pr-lint/` with shell-based fixtures executed via a small runner. The linter logic from T4 is extracted to `scripts/ci/pr-lint-check.sh` so it is unit-testable outside GitHub Actions (the workflow sources the same script). <!-- orianna: ok — prospective paths not yet created -->

- **T1 (xfail, protects user-flow-no-visual-delta invariant)**: fixture PR body with no `QA-Report:`/`QA-Waiver:` marker, diff touching only `apps/demo/routes/new-auth.ts` (a new route, no CSS/image changes). `pr-lint-check.sh` must exit non-zero and print a message containing "Rule 16" and "Akali". Commit this test as xfail first, then T4 flips it green. <!-- orianna: ok — prospective fixture paths -->

- **T2 (xfail, protects non-flow exemption)**: fixture PR body with no `QA-Report:` marker, diff touching only `scripts/deploy/foo.sh` and `architecture/notes.md`. `pr-lint-check.sh` must exit zero (exempt). Prevents false-positive regressions on infra/docs PRs. <!-- orianna: ok — prospective fixture paths -->

- **T3 (sanity, UI-path classification)**: fixture PR body missing both markers, diff touching `apps/studio/components/Button.tsx`. Linter exits non-zero. Ensures the classic UI-path path still trips the rule. <!-- orianna: ok — prospective fixture path -->

- **T4 (sanity, waiver accepted)**: fixture PR body containing `QA-Waiver: design still in flux` plus a user-flow path. Linter exits zero.

Invariants protected: (a) user-flow-change PRs cannot merge without Akali's report even when no pixels moved; (b) pure infra/docs PRs stay exempt; (c) the Akali+Playwright-MCP requirement is enforceable, not aspirational.

## References

- `CLAUDE.md` rule 16 (current wording, line 93)
- `.claude/agents/akali.md` (canonical Akali def, Playwright MCP config on line 10-14)
- `architecture/pr-rules.md` (target for T2 restatement)
- `.github/pull_request_template.md` (QA-Report row on line 24)
- `assessments/qa-reports/2026-04-22-akali-*.md` (existing Akali output format) <!-- orianna: ok — directory token -->
