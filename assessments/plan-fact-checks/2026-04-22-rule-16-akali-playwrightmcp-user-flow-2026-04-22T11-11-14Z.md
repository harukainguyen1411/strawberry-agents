---
plan: plans/proposed/personal/2026-04-22-rule-16-akali-playwrightmcp-user-flow.md
checked_at: 2026-04-22T11:11:14Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 18
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** `.claude/agents/akali.md` (L15) | **Anchor:** `test -e .claude/agents/akali.md` | **Result:** exists | **Severity:** info (C2a clean pass)
2. **Step C — Claim:** `architecture/pr-rules.md` (L35, L89) | **Anchor:** `test -e` | **Result:** exists | **Severity:** info (C2a clean pass)
3. **Step C — Claim:** `agents/evelynn/CLAUDE.md` (L43) | **Anchor:** `test -e` | **Result:** exists | **Severity:** info (C2a clean pass)
4. **Step C — Claim:** `agents/sona/CLAUDE.md` (L43) | **Anchor:** `test -e` | **Result:** exists | **Severity:** info (C2a clean pass)
5. **Step C — Claim:** `CLAUDE.md` (L15, L27, L36, L87) | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
6. **Step C — Claim:** `tdd-gate.yml` (L17) | **Result:** non-internal-prefix path token; C2b category; no filesystem check performed | **Severity:** info
7. **Step C — Claim:** `.github/pull_request_template.md` (L59, L90) | **Result:** non-internal-prefix path token (`.github/workflows/` is the only internal-prefix under `.github/`, per contract §5b); C2b category; no filesystem check performed | **Severity:** info
8. **Step C — Suppressed (L17):** author-suppressed via `<!-- orianna: ok -->` — tokens `.github/workflows/`, `.github/pull_request_template.md`, `.claude/agents/akali.md`, `.github/workflows/pr-lint.yml` | **Severity:** info (author-suppressed)
9. **Step C — Suppressed (L28):** author-suppressed via `<!-- orianna: ok -->` — token `assessments/qa-reports/` | **Severity:** info (author-suppressed)
10. **Step C — Suppressed (L51):** author-suppressed via `<!-- orianna: ok -->` — token `.github/workflows/pr-lint.yml` | **Severity:** info (author-suppressed)
11. **Step C — Suppressed (L52):** author-suppressed via `<!-- orianna: ok -->` — tokens `apps/*/app/**`, `apps/*/components/**`, `apps/*/pages/**`, `apps/*/routes/**`, `apps/*/forms/**`, `apps/*/auth/**`, `apps/*/session/**`, and keyword phrases | **Severity:** info (author-suppressed)
12. **Step C — Suppressed (L67):** author-suppressed — tokens `scripts/hooks/tests/pr-lint/`, `scripts/ci/pr-lint-check.sh` | **Severity:** info (author-suppressed)
13. **Step C — Suppressed (L68):** author-suppressed — tokens `scripts/hooks/tests/pr-lint/`, `scripts/ci/pr-lint-check.sh` | **Severity:** info (author-suppressed)
14. **Step C — Suppressed (L73):** author-suppressed — tokens `scripts/hooks/tests/pr-lint/`, `scripts/ci/pr-lint-check.sh` | **Severity:** info (author-suppressed)
15. **Step C — Suppressed (L75):** author-suppressed — token `apps/demo/routes/new-auth.ts` and related fixture tokens | **Severity:** info (author-suppressed)
16. **Step C — Suppressed (L77):** author-suppressed — tokens `scripts/deploy/foo.sh`, `architecture/notes.md` | **Severity:** info (author-suppressed)
17. **Step C — Suppressed (L79):** author-suppressed — token `apps/studio/components/Button.tsx` | **Severity:** info (author-suppressed)
18. **Step C — Suppressed (L91):** author-suppressed — token `assessments/qa-reports/2026-04-22-akali-*.md` | **Severity:** info (author-suppressed)

## External claims

None. Step E trigger heuristic did not fire: no URLs cited, no pinned library versions, no RFC/spec citations. Vendor names (Playwright, GitHub Actions) are on the allowlist; tool names (`gh`, `yamllint`, `bats`) are implicitly allowlisted per allowlist §Usage.
