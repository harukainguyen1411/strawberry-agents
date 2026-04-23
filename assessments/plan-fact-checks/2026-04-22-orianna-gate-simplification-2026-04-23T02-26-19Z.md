---
plan: plans/proposed/personal/2026-04-22-orianna-gate-simplification.md
checked_at: 2026-04-23T02:26:19Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 26
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `plans/**` (L54) | **Anchor:** `test -e plans/**` | **Result:** not found — token is a literal glob not a real path; C2a internal-prefix (`plans/`) so strict-default applies. Add `<!-- orianna: ok -->` to suppress (compare L62 / L66 where the author already suppresses similar glob tokens), or rephrase to reference the `plans/` directory without the `**` glob. | **Severity:** block

## Warn findings

None.

## Info findings

### C2a path anchors confirmed (clean pass)

1. **Step C — Claim:** `agents/memory/agent-network.md` (L44) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
2. **Step C — Claim:** `.claude/_script-only-agents/orianna.md` (L44) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
3. **Step C — Claim:** `scripts/orianna-sign.sh` (L48) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
4. **Step C — Claim:** `scripts/orianna-verify-signature.sh` (L48) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
5. **Step C — Claim:** `scripts/orianna-hash-body.sh` (L48) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
6. **Step C — Claim:** `scripts/orianna-fact-check.sh` (L48) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
7. **Step C — Claim:** `scripts/plan-promote.sh` (L48) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
8. **Step C — Claim:** `scripts/_lib_orianna_gate_implemented.sh` (L48) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
9. **Step C — Claim:** `scripts/_lib_orianna_gate_inprogress.sh` (L48) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
10. **Step C — Claim:** `architecture/plan-lifecycle.md` (L77, L103) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
11. **Step C — Claim:** `architecture/key-scripts.md` (L77) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
12. **Step C — Claim:** `scripts/hooks/` (L98) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
13. **Step C — Claim:** `scripts/hooks/test-hooks.sh` (L98) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
14. **Step C — Claim:** `plans/implemented/2026-04-20-orianna-gated-plan-lifecycle.md` (L104) | **Anchor:** `test -e` | **Result:** found | **Severity:** info
15. **Step C — Claim:** `.claude/_script-only-agents/orianna.md` (L105) | **Anchor:** `test -e` | **Result:** found | **Severity:** info

### C2b non-internal-prefix path tokens (no filesystem check performed)

16. **Step C — Claim:** `test-orianna-*.sh`, `orianna-memory-audit.sh`, `orianna-pre-fix.sh`, `_lib_orianna_architecture.sh`, `_lib_orianna_estimates.sh` (L48) | **Note:** bare filenames with `.sh`; C2b category; no filesystem check performed | **Severity:** info
17. **Step C — Claim:** `git-identity.sh` (L72) | **Note:** bare filename; C2b; no filesystem check | **Severity:** info
18. **Step C — Claim:** `CLAUDE.md` (L77, L102) | **Note:** bare filename; C2b; no filesystem check | **Severity:** info
19. **Step C — Claim:** `README.md` (L84) | **Note:** bare filename; C2b; no filesystem check | **Severity:** info
20. **Step C — Claim:** `test-*.sh` (L98) | **Note:** bare filename glob; C2b; no filesystem check | **Severity:** info

### Author-suppressed lines (`<!-- orianna: ok -->`)

21. **Step C — Suppressed (L19–L22, L28):** prospective paths for Orianna agent relocation and archive dirs, intentionally authorized by author | **Severity:** info
22. **Step C — Suppressed (L37, L39, L44 commentary, L49–L50):** prospective + archive paths in T1/T2 detail blocks | **Severity:** info
23. **Step C — Suppressed (L55, L60, L62–L67):** disposable sweep script, hook archive paths, glob patterns in hook logic (T3/T4) | **Severity:** info
24. **Step C — Suppressed (L71, L78–L79):** T5 identity-bootstrap paths and T6 architecture archive paths | **Severity:** info
25. **Step C — Suppressed (L83, L85, L91, L93, L96, L106):** fact-check freeze references, hypothetical test fixture paths, references section | **Severity:** info

### Step A / Step B / Step D / Step E

26. **Step A — Frontmatter:** `owner: karma` present | **Result:** pass | **Severity:** info
    **Step B — Gating markers:** no `## Open questions` / `## Gating questions` / `## Unresolved` sections; no unresolved `TBD`/`TODO`/`Decision pending` markers in gating sections | **Result:** pass
    **Step D — Sibling files:** `find plans -name "2026-04-22-orianna-gate-simplification-{tasks,tests}.md"` returned no results | **Result:** pass — single-file layout confirmed
    **Step E — External claims:** no Step E triggers fired (no cited URLs, no library/SDK version references, no RFC citations in the plan body) | **Result:** 0 external calls used

## External claims

None.
