---
plan: plans/approved/work/2026-04-20-session-state-encapsulation.md
checked_at: 2026-04-21T06:18:20Z
auditor: orianna
check_version: 2
gate: task-gate-check
claude_cli: present
block_findings: 4
warn_findings: 0
info_findings: 1
---

## Block findings

1. **Step B — estimate_minutes (missing field):** ZERO task entries under `## Tasks` declare an `estimate_minutes:` field. `grep -c "estimate_minutes:" <plan>` returns 0. Every task from SE.0.1 through SE.F.6 (~36 tasks) is non-compliant. Add `estimate_minutes: <1-60>` to every task entry per §D4. | **Severity:** block

2. **Step B — alternative time unit literals:** the literal `hours` appears in the Tasks section at line 742 (`| Phase | Tasks | Estimate (person-hours) |`) and line 751 (`| **Total extraction PRs (SE.0–SE.E)** | **30** | **~16 person-hours** |`). AI-minutes (`estimate_minutes:`) is the only accepted unit per §D4; the person-hours summary table must be removed or replaced with AI-minute aggregates. | **Severity:** block

3. **Step C — no qualifying test task:** `tests_required: true` is declared in the frontmatter, but no task in `## Tasks` satisfies the qualification rule. No task has `kind: test` inline metadata, and no task heading matches `^(write|add|create|update) .* test` (case-insensitive). The nine test-authoring tasks (SE.A.1/3/5/7/9/11, SE.B.1, SE.D.1, SE.E.1) are titled `xfail tests for ...` / `xfail test for ...` / `xfail tests asserting ...`, which start with `xfail` and fall outside the regex. Rename at least one test task to a qualifying form (e.g. `Write xfail tests for session_store dataclasses`) OR add `kind: test` to the task metadata. | **Severity:** block

4. **Step F — approved-signature body edits:** signature present and `orianna-verify-signature.sh ... approved` returns OK (hash=`8f50da643f...`, commit=`cfd5d689`). However, advancing to `in-progress` requires the approved signature to still cover the latest body; if any of the block-remediation edits above (B1, B2, C) are made, the approved signature will be invalidated and must be re-signed via `scripts/orianna-sign.sh <plan> approved` before re-running this gate. Flagged as a procedural block because the plan cannot promote without re-signing after the Step B/C fixes. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step A / D — structural sections present:** `## Tasks` section exists at line 337 with substantive content (~415 lines, 36 tasks across phases SE.0–SE.F). `## Test plan` section exists at line 755 with non-empty content (I1–I4 test layers). Step E grep found no sibling `-tasks.md` / `-tests.md` files under `plans/`. These three structural checks pass; the blockers are entirely on estimate format (Step B) and test-task naming (Step C). | **Severity:** info
