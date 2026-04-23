---
plan: plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md
checked_at: 2026-04-21T11:49:05Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 8
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** all required fields present (`status: proposed`, `owner: swain`, `created: 2026-04-21`, `tags: [demo-studio, vanilla-api, re-architecture, work]`). `concern: work` declared — Step C routing flipped to work workspace (`~/Documents/Work/mmp/workspace/`, present). | **Severity:** info

2. **Step B — Gating questions:** §10 "Open questions" contains six enumerated questions; each has an explicit `Pick: (x)` resolution inline. No unresolved `TBD` / `TODO` / `Decision pending` / standalone `?` markers detected in a gating section. | **Severity:** info

3. **Step C — Claim:** `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md` (line 40) | **Anchor:** `test -e` against strawberry-agents working tree | **Result:** exists; author-suppressed via trailing `<!-- orianna: ok -->` | **Severity:** info

4. **Step C — Claim:** `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md` (line 40) | **Anchor:** `test -e` against strawberry-agents working tree | **Result:** exists; author-suppressed | **Severity:** info

5. **Step C — Claim:** `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` (line 41) | **Anchor:** `test -e` against strawberry-agents working tree | **Result:** not present at cited path, but line is author-suppressed via trailing `<!-- orianna: ok -->`; logged as author-suppressed per §8 suppression rule | **Severity:** info

6. **Step C — Claim:** `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` (lines 49, 524) | **Anchor:** `test -e` against strawberry-agents working tree | **Result:** not present at cited path, but both lines are author-suppressed via trailing `<!-- orianna: ok -->`; logged as author-suppressed | **Severity:** info

7. **Step C — Suppression coverage note:** header comment lines 18–26 declare intent to suppress classes of tokens (work-workspace module paths, HTTP routes, Firestore paths, env-var names, SDK method names, git branch tokens, plan-lifecycle stems, prospective filenames, extension refs). Per §8 rules these markers only suppress their own line (or the immediately following line for standalone markers). The plan body's downstream repetitions of those token classes are therefore technically un-suppressed by the letter of the contract. None of them, however, matched the Step-C extraction surface (path-shaped with `/` that routes to a concrete filesystem checkout): they are Firestore document paths, HTTP route strings, Python dotted identifiers, enum values, or env-var names. No Step-C block or warn followed. Author may wish to either (a) inline per-line markers on the repeat sites, or (b) propose an extension to the suppression grammar that supports block-level scope, for future plans of similar shape. | **Severity:** info

8. **Step D — Sibling files:** `find plans -name "2026-04-21-demo-studio-v3-vanilla-api-ship-tasks.md" -o -name "...-tests.md"` returned zero matches. §D3 one-plan-one-file rule satisfied. | **Severity:** info

## External claims

None. Step E trigger-heuristic matches (Anthropic SDK calls: `client.beta.agents.create`, `anthropic.messages.create`, `anthropic.messages.stream`, `client.messages.stream`; model `claude-sonnet-4-6`; built-in tool type `web_search_20241022`) appear exclusively on lines covered by author suppression (line 22 header plus inline `<!-- orianna: ok -->` markers on lines 53, 58, 65, 117, 168, 174, 233, 237, 285, 324, 346, etc., plus fenced code blocks consumed by the §3 / §5 shape illustrations). Per §8 + prompt §E.2, suppressed external claims are not dispatched to WebFetch / context7 / WebSearch. No external budget consumed.

