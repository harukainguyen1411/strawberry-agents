---
plan: plans/proposed/personal/2026-04-22-rule-16-akali-playwrightmcp-user-flow.md
checked_at: 2026-04-22T11:20:48Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 14
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `owner: Karma` present | **Severity:** info
2. **Step C — Claim:** `.claude/agents/akali.md` | **Anchor:** `test -e .claude/agents/akali.md` | **Result:** hit (C2a clean pass) | **Severity:** info
3. **Step C — Claim:** `architecture/pr-rules.md` | **Anchor:** `test -e architecture/pr-rules.md` | **Result:** hit (C2a clean pass) | **Severity:** info
4. **Step C — Claim:** `agents/evelynn/CLAUDE.md` | **Anchor:** `test -e agents/evelynn/CLAUDE.md` | **Result:** hit (C2a clean pass) | **Severity:** info
5. **Step C — Claim:** `agents/sona/CLAUDE.md` | **Anchor:** `test -e agents/sona/CLAUDE.md` | **Result:** hit (C2a clean pass) | **Severity:** info
6. **Step C — Claim:** `CLAUDE.md` | **Anchor:** n/a | **Result:** C2b (non-internal-prefix path token; no filesystem check performed) | **Severity:** info
7. **Step C — Claim:** `.github/pull_request_template.md` | **Anchor:** n/a | **Result:** C2b (`.github/` alone is not an internal-prefix; only `.github/workflows/` is — no filesystem check performed) | **Severity:** info
8. **Step C — Claim:** line 17 (context paragraph ending `<!-- orianna: ok -->`) — tokens `.github/workflows/`, `tdd-gate.yml`, `QA-Report:`, `.github/pull_request_template.md`, `.claude/agents/akali.md`, `.github/workflows/pr-lint.yml` | **Result:** author-suppressed | **Severity:** info
9. **Step C — Claim:** line 28 (T1 Detail ending `<!-- orianna: ok -->`) — tokens `.claude/agents/akali.md`, `mcp__plugin_playwright_playwright__*`, `assessments/qa-reports/`, `QA-Report:` | **Result:** author-suppressed | **Severity:** info
10. **Step C — Claim:** line 51 (T4 Files ending `<!-- orianna: ok -->`) — token `.github/workflows/pr-lint.yml` | **Result:** author-suppressed (prospective file) | **Severity:** info
11. **Step C — Claim:** line 52 (T4 Detail ending `<!-- orianna: ok -->`) — tokens `pull_request`, `gh pr view --json body`, `gh pr diff --name-only`, `apps/*/app/**`, `apps/*/components/**`, `apps/*/pages/**`, `apps/*/routes/**`, `apps/*/forms/**`, `apps/*/auth/**`, `apps/*/session/**`, `QA-Report:`, `QA-Waiver:`, etc. | **Result:** author-suppressed (prospective glob patterns) | **Severity:** info
12. **Step C — Claim:** lines 67–69 (T6, `<!-- orianna: ok -->`) — tokens `scripts/ci/pr-lint-check.sh`, `scripts/hooks/tests/pr-lint/` (prospective) | **Result:** author-suppressed | **Severity:** info
13. **Step C — Claim:** lines 73, 75, 77, 79 (Test plan, `<!-- orianna: ok -->`) — prospective fixture paths | **Result:** author-suppressed | **Severity:** info
14. **Step C — Claim:** line 91 (References, `<!-- orianna: ok -->`) — token `assessments/qa-reports/2026-04-22-akali-*.md` (directory glob) | **Result:** author-suppressed | **Severity:** info

## External claims

None. (No URLs, version pins, or named third-party libraries/SDKs triggered Step E heuristic. `Playwright MCP`, `GitHub Actions` are on the vendor allowlist.)
