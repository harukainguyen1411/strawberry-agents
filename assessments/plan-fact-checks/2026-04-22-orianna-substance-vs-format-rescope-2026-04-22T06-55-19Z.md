---
plan: plans/proposed/personal/2026-04-22-orianna-substance-vs-format-rescope.md
checked_at: 2026-04-22T06:55:19Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 16
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

<!-- Step A: all four frontmatter fields present and well-formed. -->
1. **Step A — Frontmatter:** `status: proposed`, `owner: swain`, `created: 2026-04-22`, `tags: [orianna-gate, plan-lifecycle, scripts, hooks, governance, rescope]` all present and well-formed | **Severity:** info

<!-- Step B: all 6 OQs explicitly resolved. -->
2. **Step B — Gating questions:** `## 10. Gating questions` contains OQ-1 through OQ-6, each ending with an explicit `**Resolved:**` line. No open `TBD` / `TODO` / `Decision pending` / unresolved `?` markers inside the gating section | **Severity:** info
3. **Step B — Self-referential markers:** backtick-cited literals ``TBD`` / ``TODO`` / ``Decision pending`` appearing in §3.2 row PA-5 are spec citations (describing what the gating-question scan itself looks for), not open gating markers. No action | **Severity:** info

<!-- Step C: internal-prefix paths verified via test -e against working tree. -->
4. **Step C — Internal paths (assessments/):** `assessments/plan-fact-checks/2026-04-21-demo-studio-v3-e2e-ship-v2-2026-04-21T09-50-32Z.md`, `.../2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-28-28Z.md`, `.../2026-04-22-explicit-model-on-agent-defs-2026-04-22T02-34-14Z.md` — all resolved via `test -e` | **Severity:** info
5. **Step C — Internal paths (plans/):** `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md` — resolved | **Severity:** info
6. **Step C — Internal paths (scripts/):** `scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`, `scripts/orianna-hash-body.sh`, `scripts/plan-promote.sh`, `scripts/hooks/pre-commit-zz-plan-structure.sh`, `scripts/_lib_orianna_architecture.sh`, `scripts/_lib_orianna_estimates.sh`, `scripts/_lib_plan_structure.sh`, `scripts/fact-check-plan.sh`, `scripts/test-fact-check-concern-root-flip.sh`, `scripts/test-fact-check-false-positives.sh`, `scripts/test-fact-check-work-concern-routing.sh`, `scripts/test-orianna-lifecycle-smoke.sh` — all resolved | **Severity:** info
7. **Step C — Internal paths (architecture/):** `architecture/plan-lifecycle.md` — resolved | **Severity:** info
8. **Step C — Internal paths (agents/):** `agents/orianna/prompts/plan-check.md`, `agents/orianna/prompts/task-gate-check.md`, `agents/orianna/prompts/implementation-gate-check.md`, `agents/orianna/claim-contract.md`, `agents/orianna/allowlist.md`, `agents/orianna/learnings/index.md` — all resolved | **Severity:** info

<!-- Step C: unknown path prefix — feedback/ is not on the personal routing table. -->
9. **Step C — Unknown prefix:** `feedback/2026-04-21-orianna-signing-latency.md` — prefix `feedback/` not on personal-concern routing table; file does exist on working tree. Add to contract if load-bearing | **Severity:** info
10. **Step C — Unknown prefix:** `feedback/2026-04-21-orianna-signing-followups.md` — prefix `feedback/` not on personal-concern routing table; file does exist on working tree | **Severity:** info

<!-- Step C: HTTP-route-shaped tokens — path-shaped but no recognized prefix. -->
11. **Step C — HTTP-route tokens (path-shaped, unrouted):** `/build`, `/verify`, `/logs`, `/approve` (line 32), `/auth/login` (line 355). Path-shaped (contain `/`) but bare-root prefix is not on any routing table. Logged as info per routing-rules §5b. These are META-EXAMPLES cited by the plan itself to motivate the substance-vs-format rescope | **Severity:** info

<!-- Step C: author-suppressed lines per suppression syntax in claim-contract.md §8. -->
12. **Step C — Author-suppressed (`<!-- orianna: ok -->`):** lines 33, 47, 106, 110, 128, 138, 163, 165, 177, 181, 194, 196, 217, 219, 230, 252, 254, 269, 272, 292, 302, 318, 322, 340, 349, 356, 368, 385, 409, 420, 422, 434, 435, 441, 442 — all claims on these lines explicitly authorized by the plan author. No block/warn emitted | **Severity:** info

<!-- Step C: integration / named tokens. -->
13. **Step C — Integration names:** `context7`, `WebFetch`, `WebSearch` — all appear in allowlist §1 | **Severity:** info
14. **Step C — Agent-roster reference:** ``Orianna`` (line 315, referring to the signature mechanism) — roster name per claim-contract §2. Not an integration claim | **Severity:** info

<!-- Step D: no sibling files. -->
15. **Step D — Sibling files:** `find plans -name "2026-04-22-orianna-substance-vs-format-rescope-tasks.md" -o -name "...-tests.md"` returned zero hits. §D3 one-plan-one-file rule satisfied | **Severity:** info

<!-- Step E: no external claims triggered. -->
16. **Step E — External claims:** no URLs, version numbers, library/SDK/framework names off the allowlist, or RFC references that trigger Step E verification. All cross-system references are to internal agents/allowlisted vendors. Zero external tool calls used | **Severity:** info

## External claims

None.
