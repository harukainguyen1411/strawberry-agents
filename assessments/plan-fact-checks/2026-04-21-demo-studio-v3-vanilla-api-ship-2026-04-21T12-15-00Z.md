---
plan: plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
checked_at: 2026-04-21T12:15:00Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 6
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all required fields present and well-formed. `status: proposed` ✓, `owner: swain` ✓, `created: 2026-04-21` ✓, `tags: [demo-studio, vanilla-api, re-architecture, work]` ✓. `concern: work` declared — Step C routing resolves non-opt-back paths against `~/Documents/Work/mmp/workspace/` (present on disk). | **Severity:** info

2. **Step B — Gating questions:** §10 "Open questions" enumerates six questions; each carries an explicit inline `Pick: (x)` resolution (Q1=a, Q2=a, Q3=a, Q4=a, Q5=a, Q6=b). No unresolved `TBD` / `TODO` / `Decision pending` / standalone `?` markers found inside a gating section. | **Severity:** info

3. **Step C — Path-anchor sweep:** strawberry-agents opt-back references verified present — `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md` (§1 line 41), `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md` (§1 line 41). Work-workspace references verified present under `~/Documents/Work/mmp/workspace/` — `company-os/tools/demo-studio-v3/agent_proxy.py`, `company-os/tools/demo-studio-v3/setup_agent.py`, `company-os/tools/demo-studio-v3/config_mgmt_client.py`, `company-os/tools/demo-studio-v3/factory_bridge.py`, `company-os/tools/demo-studio-mcp/` (exists as directory). All remaining path-shaped tokens resolve on lines carrying a literal `<!-- orianna: ok -->` marker (author-suppressed per §8) or are not filesystem paths at all (HTTP routes on `/session/...`, `/v1/config/...`, `/dashboard`; Firestore collection paths `demo-studio-sessions/{id}/...`; Python dotted identifiers `client.beta.agents.create`, `session_store.transition_status`; env-var names `MANAGED_*`, `DEMO_STUDIO_MCP_*`; git branch tokens `integration/demo-studio-v3-*`). | **Severity:** info

4. **Step C — Suppression coverage note:** header comment lines 19–27 document author intent to suppress large classes of tokens (work-workspace module paths, HTTP routes, Firestore paths, env-var names, SDK method names, git branch tokens, plan-lifecycle stems, prospective retirement-ADR filenames, bare `.md`/`.env.example` refs). Most lines contain a proper trailing `<!-- orianna: ok -->` token (lines 25, 26, 27) and therefore actively suppress tokens on their own lines; lines 19–24 embed the marker inside a longer HTML comment (em-dash continuation) and do not match the literal marker grammar, so they function as prose documentation rather than active suppression. No downstream body line produced a Step-C block or warn — the unsuppressed repeats are all HTTP routes, Firestore paths, Python dotted identifiers, or env-var names, none of which are filesystem paths under the routing rules. Author may wish to inline per-line markers on the repeat sites in a follow-up, or propose a block-scope suppression grammar. | **Severity:** info

5. **Step D — Sibling files:** `find plans -name "2026-04-21-demo-studio-v3-vanilla-api-ship-tasks.md" -o -name "...-tests.md"` returned zero matches. §D3 one-plan-one-file rule satisfied; `## Tasks` (§12/§Tasks section) and `## Test plan` are inlined in the plan body. | **Severity:** info

6. **Step E — External claims:** Step-E trigger heuristic matches are concentrated on lines covered by author suppression (Anthropic SDK calls `client.beta.agents.create`, `anthropic.messages.create`, `anthropic.messages.stream`, `client.messages.stream`; model identifier `claude-sonnet-4-6`; built-in tool type `web_search_20241022`). Suppressed external claims are not dispatched to WebFetch / context7 / WebSearch per §E.2 + §8. No external budget consumed. | **Severity:** info

## External claims

None. Step E triggers fell under author suppression; no network verification performed.
