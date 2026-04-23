---
plan: plans/proposed/personal/2026-04-22-rule-16-akali-playwrightmcp-user-flow.md
checked_at: 2026-04-22T10:46:31Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 10
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `owner: Karma` present | **Result:** pass.
2. **Step B — Gating questions:** no `## Open questions`/`## Gating questions`/`## Unresolved` section present, and no unresolved gating markers found elsewhere | **Result:** pass.
3. **Step C — Claim:** `.claude/agents/akali.md` (lines 15, 36, 80) | **Anchor:** `test -e .claude/agents/akali.md` | **Result:** exists | **Severity:** info (clean pass).
4. **Step C — Claim:** `architecture/pr-rules.md` (lines 35, 81) | **Anchor:** `test -e architecture/pr-rules.md` | **Result:** exists | **Severity:** info (clean pass).
5. **Step C — Claim:** `agents/evelynn/CLAUDE.md` (line 43) | **Anchor:** `test -e agents/evelynn/CLAUDE.md` | **Result:** exists | **Severity:** info (clean pass).
6. **Step C — Claim:** `agents/sona/CLAUDE.md` (line 43) | **Anchor:** `test -e agents/sona/CLAUDE.md` | **Result:** exists | **Severity:** info (clean pass).
7. **Step C — Author-suppressed:** line 17 (`.github/workflows/`, `tdd-gate.yml`, `QA-Report:`, `.github/pull_request_template.md`, `.claude/agents/akali.md`) | marker: `<!-- orianna: ok -->` | **Severity:** info (author-suppressed).
8. **Step C — Author-suppressed:** lines 28, 51, 52, 65, 67, 69, 71, 83 (prospective/illustrative path tokens incl. `apps/*/...` globs, `scripts/hooks/tests/pr-lint/`, `scripts/ci/pr-lint-check.sh`, `apps/demo/routes/new-auth.ts`, `apps/studio/components/Button.tsx`, `scripts/deploy/foo.sh`, `architecture/notes.md`, `assessments/qa-reports/2026-04-22-akali-*.md`) | marker: `<!-- orianna: ok -->` | **Severity:** info (author-suppressed).
9. **Step C — Non-claim / C2b skip:** `CLAUDE.md` (lines 15, 27, 36, 79), `.github/pull_request_template.md` (lines 59, 82), `pr-lint-check.sh` (line 67, unsuppressed refs) | **Note:** non-internal-prefix path tokens; C2b category; no filesystem check performed. `.github/pull_request_template.md` is not internal-prefix under personal routing (only `.github/workflows/` is opted in) | **Severity:** info.
10. **Step D — Sibling-file grep:** no `*-tasks.md` or `*-tests.md` siblings found for basename `2026-04-22-rule-16-akali-playwrightmcp-user-flow` | **Severity:** info (pass).

## External claims

None. (No cited URLs, no versioned library/SDK/framework references, no RFC citations — Step E trigger heuristic did not fire on any token. "Playwright" appears as a bare vendor name on the allowlist; "Playwright MCP" is a tool-family reference anchored via `.claude/agents/akali.md` which was verified in Step C.)
