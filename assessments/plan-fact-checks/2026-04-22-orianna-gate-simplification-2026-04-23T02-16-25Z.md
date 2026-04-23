---
plan: plans/proposed/personal/2026-04-22-orianna-gate-simplification.md
checked_at: 2026-04-23T02:16:25Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 16
warn_findings: 0
info_findings: 18
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `.claude/agents/orianna.md` (line 28) | **Anchor:** `test -e .claude/agents/orianna.md` | **Result:** not found (C2a internal-prefix). Line has no `<!-- orianna: ok -->` suppression marker. | **Severity:** block
2. **Step C — Claim:** `agents/orianna/memory/git-identity.sh` (line 39) | **Anchor:** `test -e agents/orianna/memory/git-identity.sh` | **Result:** not found (C2a). Line has no suppression marker — T5 creates this file but the prospective citation on line 39 is unmarked. | **Severity:** block
3. **Step C — Claim:** `scripts/sweep-orianna-metadata.sh` (line 55) | **Anchor:** `test -e scripts/sweep-orianna-metadata.sh` | **Result:** not found (C2a). Prospective/disposable script, unmarked. | **Severity:** block
4. **Step C — Claim:** `plans/proposed/**` (line 62) | **Anchor:** `test -e plans/proposed/**` | **Result:** not found — literal glob pattern does not resolve. If intended as a descriptive glob, mark the line with `<!-- orianna: ok -->` or rephrase to cite the bare directory `plans/proposed/`. | **Severity:** block
5. **Step C — Claim:** `plans/(approved|in-progress|implemented|archived)/**` (line 62) | **Anchor:** `test -e plans/(approved|in-progress|implemented|archived)/**` | **Result:** not found — literal glob+alternation pattern does not resolve. Suggest suppression or rephrase. | **Severity:** block
6. **Step C — Claim:** `scripts/hooks/_orianna_identity.txt` (line 63) | **Anchor:** `test -e scripts/hooks/_orianna_identity.txt` | **Result:** not found (C2a). Prospective file created by T5; line 63 reference is unmarked. | **Severity:** block
7. **Step C — Claim:** `.claude/agents/orianna.md` (line 64) | **Anchor:** `test -e .claude/agents/orianna.md` | **Result:** not found (C2a). Unmarked. | **Severity:** block
8. **Step C — Claim:** `scripts/hooks/_orianna_identity.txt` (line 64) | **Anchor:** `test -e scripts/hooks/_orianna_identity.txt` | **Result:** not found (C2a). Unmarked. | **Severity:** block
9. **Step C — Claim:** `plans/approved/**` (line 66) | **Anchor:** `test -e plans/approved/**` | **Result:** not found — glob. Suggest suppression or reword to cite directory. | **Severity:** block
10. **Step C — Claim:** `plans/in-progress/**` (line 66) | **Anchor:** `test -e plans/in-progress/**` | **Result:** not found — glob. | **Severity:** block
11. **Step C — Claim:** `plans/implemented/**` (line 66) | **Anchor:** `test -e plans/implemented/**` | **Result:** not found — glob. | **Severity:** block
12. **Step C — Claim:** `plans/archived/**` (line 66) | **Anchor:** `test -e plans/archived/**` | **Result:** not found — glob. | **Severity:** block
13. **Step C — Claim:** `plans/proposed/personal/foo.md` (line 91) | **Anchor:** `test -e plans/proposed/personal/foo.md` | **Result:** not found — hypothetical test fixture path. Add `<!-- orianna: ok -->` on the line to declare it as an illustrative example. | **Severity:** block
14. **Step C — Claim:** `plans/approved/personal/foo.md` (line 91) | **Anchor:** `test -e plans/approved/personal/foo.md` | **Result:** not found — hypothetical. Same remediation as above. | **Severity:** block
15. **Step C — Claim:** `plans/approved/personal/bar.md` (line 93) | **Anchor:** `test -e plans/approved/personal/bar.md` | **Result:** not found — hypothetical test fixture. | **Severity:** block
16. **Step C — Claim:** `.claude/agents/orianna.md` (line 96) | **Anchor:** `test -e .claude/agents/orianna.md` | **Result:** not found (C2a). Unmarked. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `owner: karma` present. | **Severity:** info
2. **Step C — Claim (author-suppressed):** all backtick tokens on line 19 (`.claude/agents/orianna.md`, `git mv`, `Promoted-By: Orianna`) — line carries `<!-- orianna: ok -->`. | **Severity:** info
3. **Step C — Claim (author-suppressed):** all backtick tokens on line 20 (multiple `plans/proposed/`, `Promoted-By: Orianna`, `harukainguyen1411`) — line carries `<!-- orianna: ok -->`. | **Severity:** info
4. **Step C — Claim (author-suppressed):** all backtick tokens on line 21 (`scripts/_archive/v1-orianna-gate/`, `scripts/hooks/_archive/v1-orianna-gate/`, `orianna_gate_version`) — line carries `<!-- orianna: ok -->`. | **Severity:** info
5. **Step C — Claim (author-suppressed):** `assessments/plan-fact-checks` on lines 22, 83, 85 — each line carries `<!-- orianna: ok -->`. | **Severity:** info
6. **Step C — Claim (author-suppressed):** all backtick tokens on line 37 (`.claude/agents/orianna.md`, `.claude/_script-only-agents/orianna.md`) — line carries `<!-- orianna: ok -->`. | **Severity:** info
7. **Step C — Claim (author-suppressed):** all backtick tokens on lines 49, 50, 60, 67, 71, 78, 79, 106 — each line carries `<!-- orianna: ok -->`. | **Severity:** info
8. **Step C — Claim:** `.claude/agents/` (line 28) | **Anchor:** `test -e .claude/agents/` | **Result:** exists. | **Severity:** info
9. **Step C — Claim:** `agents/memory/agent-network.md` (line 44) | **Anchor:** `test -e` | **Result:** exists. | **Severity:** info
10. **Step C — Claim:** `.claude/_script-only-agents/orianna.md` (line 44, 105) | **Anchor:** `test -e` | **Result:** exists. | **Severity:** info
11. **Step C — Claim:** all `scripts/orianna-*.sh`, `scripts/plan-promote.sh`, `scripts/_lib_orianna_gate_*.sh` on line 48 — all C2a tokens resolve cleanly. | **Severity:** info
12. **Step C — Claim:** `scripts/hooks/pre-commit-plan-promote-guard.sh` (line 60) — exists. | **Severity:** info
13. **Step C — Claim:** `scripts/hooks/test-plan-promote-guard.sh` (line 91) — exists. | **Severity:** info
14. **Step C — Claim:** `scripts/hooks/` and `scripts/hooks/test-hooks.sh` (line 98) — exist. | **Severity:** info
15. **Step C — Claim:** `architecture/plan-lifecycle.md`, `architecture/key-scripts.md` (lines 77, 103) — exist. | **Severity:** info
16. **Step C — Claim:** `plans/implemented/2026-04-20-orianna-gated-plan-lifecycle.md` (line 104) — exists. | **Severity:** info
17. **Step C — Claim (C2b, non-internal-prefix):** `test-orianna-*.sh`, `orianna-memory-audit.sh`, `orianna-pre-fix.sh`, `_lib_orianna_architecture.sh`, `_lib_orianna_estimates.sh`, `install-hooks.sh`, `git-identity.sh`, `CLAUDE.md`, `plan-lifecycle.md`, `key-scripts.md`, `README.md` — non-internal-prefix path tokens; C2b category; no filesystem check performed. | **Severity:** info
18. **Step D — Sibling scan:** no `*-tasks.md` or `*-tests.md` siblings found for this plan basename. | **Severity:** info

## External claims

None. Step E did not fire — the plan contains no URL, named external library/SDK, version pin, or RFC/spec citation subject to external verification.
