---
plan: plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
checked_at: 2026-04-21T11:55:37Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 2
warn_findings: 0
info_findings: 1
external_calls_used: 0
---

## Block findings

1. **Step D — Sibling:** `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship-tasks.md` exists; must be inlined into the plan body under `## Tasks` and the sibling deleted, per ADR §D3 one-plan-one-file rule. | **Severity:** block
2. **Step D — Sibling:** `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship-tests.md` exists; must be inlined into the plan body under `## Test plan` and the sibling deleted, per ADR §D3 one-plan-one-file rule. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step C — Suppression:** Extensive top-of-file `<!-- orianna: ok -->` suppression blocks (lines 18–26) and inline per-line suppression markers explicitly authorize path-shaped tokens referencing the `company-os/tools/demo-studio-v3/...`, `company-os/tools/demo-studio-mcp/...` workspace modules, Firestore collection paths, HTTP routes, env-var names, SDK method names, git branch tokens, and plan-lifecycle stems (`plans/implemented/work/`, `plans/proposed/work/`). Logged as author-suppressed; no block/warn emitted for enumerated tokens. | **Severity:** info

## External claims

None. Step E trigger heuristic fired softly on the `claude-sonnet-4-6` model identifier; no external call was issued (budget conserved; claim is an internal model-constant choice rather than a load-bearing vendor-docs assertion).
