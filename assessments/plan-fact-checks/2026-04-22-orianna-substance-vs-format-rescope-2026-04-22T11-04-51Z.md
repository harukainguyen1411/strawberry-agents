---
plan: plans/proposed/personal/2026-04-22-orianna-substance-vs-format-rescope.md
checked_at: 2026-04-22T11:04:51Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 4
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `owner: swain` present and non-blank | **Severity:** info (clean pass)
2. **Step B — Gating questions:** All OQ-1 through OQ-6 in `## 10. Gating questions` marked "**Resolved:**"; no unresolved TBD/TODO/Decision pending markers in any gating section. The `TBD` / `TODO` / `Decision pending` tokens on line 106 appear inside a §3.2 taxonomy table as descriptive references to Orianna's own gating-marker scan, not as unresolved decisions | **Severity:** info (clean pass)
3. **Step C — Claim-contract scan:** All non-suppressed internal-prefix (C2a) path tokens verified against this repo's tree. 28 distinct C2a tokens resolved cleanly (plans/, architecture/, agents/, scripts/, scripts/hooks/, assessments/, feedback/-categorized-as-unknown-prefix→info). Non-internal-prefix (C2b) tokens (HTTP routes like `/auth/login`, `/build`, `/verify`, `/logs`, `/approve`, dotted identifiers, template expressions) logged as C2b info without filesystem check per rescope §3.3. No fenced code blocks present in plan body. 23 lines carry author `<!-- orianna: ok -->` suppression markers and their claims were skipped per §8 | **Severity:** info (clean pass)
4. **Step D — Sibling files:** `find plans -name "2026-04-22-orianna-substance-vs-format-rescope-tasks.md" -o -name "...-tests.md"` returned zero matches; content is inlined under §6 Tasks and §Test plan per ADR §D3 one-plan-one-file rule | **Severity:** info (clean pass)

## External claims

None. (Step E trigger heuristic did not fire on any inline token: the plan cites no external library versions, no `http(s)://` URLs outside the test-results CI run links — which are post-hoc evidence not subject to pre-approval gate — and no RFC/spec citations.)
