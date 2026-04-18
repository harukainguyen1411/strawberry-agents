# Orianna v1 Finalization — Re-run of O6.5 and O6.8

Date: 2026-04-18
Session: Orianna v1 finalization after restart

## O6.5 — memory-audit script (orianna-memory-audit.sh)

**Result: PASS. Exit code 0.**

- Script ran end-to-end with the corrected CLI flags (`-p --agent orianna --dangerously-skip-permissions`)
- Report written to `assessments/memory-audits/2026-04-18-memory-audit.md`
- Script committed the report (chore: prefix) and pushed — commit `fae01e9`
- Findings: block:15, warn:53, info:4 — these are real stale refs in memory files across agents, not script failures; the audit is working as designed

## O6.8 — dogfood the gate against Orianna's own plans

### ADR plan (orianna-fact-checker.md)

**Result: CLEAN. block=0, warn=1, info=3. Exit code 0.**

- Warn 1: cross-repo checkout absent (expected; strawberry-app checkout absent)
- Info 1: in-repo paths all resolve cleanly
- Info 2: `agents/memory/agents-table.md` now exists, contradicting a stale assertion in the ADR §5.2
- Info 3: org/repo slug tokens not routed
- Gate correctly returns exit 0

### Tasks plan (orianna-fact-checker-tasks.md)

**Result: BLOCKED. block=2, warn=1, info=6. Exit code 1.**

Block 1: `plans/approved/2026-04-19-orianna-fact-checker.md` at body lines 712 and 731 in O6.8 task.
- These are stale in-body text references: "Move the parent plan (`plans/approved/...`)" and "Files touched: `plans/approved/...`"
- The frontmatter was fixed in 15f9b44, but the O6.8 task body text still references the old `approved/` path
- This is a real stale path claim that violates the gate

Block 2: `Firebase GitHub App` — integration name used as a meta-example/description in O2.2 task body
- Appears in prose (not backticks) at lines 176, 184, 546, 552
- Per claim-contract §4 strict default, unanchored Section-2 integration names block
- This is the gate working correctly on its own example case

**Promotion HALTED per task briefing — do not promote to implemented/.**

## Script-level bug discovered: report picker picks wrong report for orianna-fact-checker.md

When running fact-check against `2026-04-19-orianna-fact-checker.md`, the
script's `for f in "$REPORT_DIR"/${PLAN_BASENAME}-*.md` loop uses
`PLAN_BASENAME=2026-04-19-orianna-fact-checker` which also matches
`2026-04-19-orianna-fact-checker-tasks-*.md` files (prefix match). Since
`-tasks-` sorts after the timestamp strings alphabetically (`t` > `2`),
the loop's `latest_report` ends up pointing at the tasks report, not the
ADR's own fresh report.

Impact: `scripts/orianna-fact-check.sh` reads block_count from the WRONG
report when the two plans share the same basename prefix. Script exits 1
falsely, even though the ADR's actual fresh report shows block=0.

The correct exit (from Orianna's LLM stdout output) IS 0, but the
post-check block_count extraction in the shell picks up the stale tasks
report. This is a bug to fix in orianna-fact-check.sh — the report picker
should match EXACT basename (not prefix).

## What still needs to happen before Orianna v1 can be declared shipped

1. Fix the two block findings in the tasks plan:
   - Lines 712, 731: update body text of O6.8 task from `plans/approved/...`
     to `plans/in-progress/...` (Yuumi or any plan-editing agent)
   - The `Firebase GitHub App` mentions: either add an `<!-- orianna: ok -->`
     suppression comment (if intentional meta-examples), or verify the
     allowlist.md suppresses them correctly, or reword to avoid backtick
     extraction

2. Fix the report-picker bug in orianna-fact-check.sh (Jayce or Kayn)

3. Re-run dogfood on both plans after fixes

4. Only after re-run shows block=0 on both plans: promote both to
   `implemented/` via `git mv` + frontmatter rewrite + commit
