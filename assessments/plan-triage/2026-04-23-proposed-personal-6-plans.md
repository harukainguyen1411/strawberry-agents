# Plan Triage — 6 Proposed Personal Plans
**Date:** 2026-04-23
**Triager:** Ekko
**PR #30 context:** Orianna v2 trailer-based gate landed today (add2027); v1 scripts archived.

---

## Executive Summary

Of the 6 proposed personal plans, **1 should promote as-is** (pre-lint-rename-aware), **2 need revisions before promoting** (subagent-permission-reliability, coordinator-decision-feedback), **1 should be deferred** pending prerequisite decisions (agent-feedback-system), and **2 should be closed or significantly deferred** due to scope/dependency concerns (daily-agent-repo-audit-routine, retrospection-dashboard). Concretely: 1 promote, 2 revise, 1 defer, 2 close.

---

## Plan 1 — `2026-04-21-pre-lint-rename-aware.md`

**Title:** Rename-aware Rule 4 in the plan-structure pre-commit hook

**Premise:** `git mv` renames cause the plan-structure pre-commit hook to flag every path token in the entire file body as a Rule 4 violation, because the staged diff renders the whole new-side as additions-only; the fix is blob-to-blob diffing for rename entries.

**Estimated complexity:** Quick (90-minute total estimate, 5 tasks, single-file hook change plus tests).

**Still relevant post-PR-30?** Yes and more urgent. PR #30 landed the v2 gate; plan promotions still flow through `plan-promote.sh` which does `git mv`, so every v2-gated plan promotion still hits this hook misbehavior. Nothing in PR #30 changes the staged-diff scoping logic in `pre-commit-zz-plan-structure.sh`. This is a live pain point confirmed by Ekko session #65 (218 tool turns spent mass-suppressing tokens on a single promotion).

**Dependencies:** `plans/approved/personal/2026-04-21-plan-prelint-shift-left.md` (approved, implemented — the hook this plan extends is PR #15's product). No blockers.

**Recommendation:** KEEP-AS-IS. Promote immediately — this unblocks every future plan promotion and is the highest-leverage quick fix in the proposed queue.

---

## Plan 2 — `2026-04-21-coordinator-decision-feedback.md`

**Title:** Coordinator decision-feedback and preference learning — predict, record, calibrate

**Premise:** Every a/b/c decision Duong answers is consumed in-session and lost; there is no mechanism to pre-commit predictions, aggregate patterns, or calibrate coordinator recommendations over time; this plan builds a local file-based predict-record-calibrate loop.

**Estimated complexity:** Complex (425-minute estimate, 12 tasks, touches scripts, skills, agent defs, CLAUDE.md files, and architecture docs).

**Still relevant post-PR-30?** Yes — orthogonal to the gate mechanics. The plan's dependencies are on `memory-consolidation-redesign` (now implemented) and `memory-consolidate.sh` (already shipped). The script re-extension in T4 is straightforward.

**Dependencies:** `memory-consolidation-redesign` — implemented. `memory-consolidate.sh` — shipped. No hard blockers remain, but the plan's 5 open questions (OQ1–OQ5) need Duong answers before tasking starts. OQ5 in particular recommends serializing this plan after memory-consolidation hits `in-progress`, which it now has cleared fully (implemented); that serial ordering is satisfied. OQ1–OQ4 are design questions Duong should answer inline.

**Concerns:** `agents/evelynn/CLAUDE.md` and `.claude/agents/evelynn.md` edits (T9, T10) have historically been harness-denied to Ekko (confirmed in Ekko memory 2026-04-20). Those tasks need either Evelynn-direct or Duong-manual action.

**Recommendation:** REVISE — resolve OQ1–OQ5 in the plan body before promoting, and annotate T9/T10 with "requires Evelynn-direct or Duong-manual" to avoid a blocked subagent mid-implementation.

---

## Plan 3 — `2026-04-21-daily-agent-repo-audit-routine.md`

**Title:** Daily agent-repo audit routine — drift detection via Claude Code Routines

**Premise:** Repo drift (stale CLAUDE.md rule references, orphan architecture docs, undocumented structure, rule duplication, upstream feature gaps) accumulates faster than manual one-shot audits catch it; a daily Claude Code Routine dispatching 5 parallel subagent audit dimensions would run automatically against checked-in state.

**Estimated complexity:** Complex (14 tasks, 750+ estimated minutes; spans new `audits/` directory, tracker schema, 5 audit dimension skills, orchestrator script, Routine config step, and a 7-day observation period).

**Still relevant post-PR-30?** Conceptually yes. The drift problems it targets are real and recur. However, the plan depends on **Claude Code Routines** (web-infrastructure scheduled runs) — a feature the plan credits to a "2026 Claude Code blog post." This is unverified; the feature may not be generally available or may work differently than the plan assumes. T4 and T11 are explicitly human-only steps (Duong creates the Routine entry in the web UI). If Routines are not available or behave differently, the orchestration design collapses.

**Dependencies:**
- T12 depends on retrospection-dashboard Phase 1 landing (that plan is also proposed and complex).
- The feedback-system plan (Plan 4 below) is a sibling; T12 of the feedback plan edits this plan's §D10.
- Claude Code Routines availability — needs verification before committing to this architecture.

**Recommendation:** DEFER — validate that Claude Code Routines work as described (T4 prerequisite) before investing in the 13 preceding tasks. Suggest Duong does a 30-minute spike to confirm the scheduling primitive exists and behaves as expected; if it does, re-open with a verified T4. If not, the architecture needs rethinking (cron via launchd + `claude` CLI would be an alternative).

---

## Plan 4 — `2026-04-21-agent-feedback-system.md`

**Title:** Continuous agent-feedback system

**Premise:** Agents encounter friction (hook surprises, schema mismatches, retry loops, documentation that contradicts reality) but have no structured channel to record it; a 5-layer system (write / broadcast / encouragement / ritual / consolidation) would capture friction into a growing corpus and graduate high-signal entries into improvement plans.

**Estimated complexity:** Complex (13 tasks, ~700+ estimated minutes; touches `feedback/`, `scripts/`, 10 shared agent rule files, 4 skills, `end-session`, `pre-compact-save`, `end-subagent-session`, and the daily audit routine).

**Still relevant post-PR-30?** Yes. The friction it targets is persistent and independent of the gate mechanics.

**Dependencies:**
- T12 depends on the daily-audit-routine plan (Plan 3 above) being in-progress or further. Since Plan 3 is deferred pending Routines verification, T12 is blocked.
- T6 (`sync-shared-rules.sh` depth-2 includes) depends on the existing sync mechanism; that mechanism's current state needs verification.
- The plan explicitly calls itself a "sibling" of Plans 3 and 5 (retrospection-dashboard) with cross-edits. All three landing together is the ideal but produces a large coordinated implementation risk.
- `scripts/feedback-index.sh` uses a Node YAML shim (T2) — introduces a Node runtime dependency in a POSIX-bash-only `scripts/` folder; this may conflict with CLAUDE.md Rule 10.

**Recommendation:** DEFER — the sibling dependency on Plan 3 (deferred) and the cross-edit coupling with Plans 3 and 5 mean this can't cleanly land until those decisions are resolved. Revisit after Plan 3's Routines validation spike.

---

## Plan 5 — `2026-04-21-retrospection-dashboard.md`

**Title:** Retrospection and Observability Dashboard

**Premise:** Agent work, Duong's goals, and costs are scattered across 5 data sources that don't compose; a new localhost-only SPA (`strawberry-retro/`) would join them into a single surface with a system-vs-product axis, weekly/monthly views, and a capture flow for ideas.

**Estimated complexity:** Complex (the plan is very large — §D1 through §D9 span design decisions for a new repo, a new app, 4 data sources, a system-vs-product labeling model, a capture flow, multiple phases, and explicit retro-dashboard integration touchpoints with Plans 3 and 4).

**Still relevant post-PR-30?** Yes — the underlying need (observability over what the agent system is doing) is real. However, the plan's scope is a multi-month greenfield project in a new repo with no existing skeleton.

**Dependencies:**
- Depends on `subagents.json` from `2026-04-19-usage-dashboard-subagent-task-attribution.md` (status: proposed, not yet implemented).
- Plan 3 (audit routine) would write to a tracker that Plan 5's ingestor reads — coupling the two.
- A new sibling repo (`~/Documents/Personal/strawberry-retro/`) needs to be created; no current scaffolding.
- The 3 sibling proposed plans referenced in §1.1 are all unresolved.

**Recommendation:** CLOSE (in current form) — scope is too large to promote cleanly, and the prerequisite `subagent-task-attribution` plan is itself unimplemented. Recommend splitting: (a) a narrow "retro-ingestor" plan that only joins `ccusage` outputs + git log + agent memory into `retro.json`, demoting the full SPA to a future phase; (b) a separate "retro-SPA" plan that builds on (a) once the data shape is proven. The current monolithic plan is unlikely to ship in any reasonable window.

---

## Plan 6 — `2026-04-22-subagent-permission-reliability.md`

**Title:** Subagent permission-denial reliability — diagnose and mitigate

**Premise:** Multiple `bypassPermissions` subagents intermittently hit persistent Edit/Write/Bash permission denials under parallel-dispatch load; a `PostToolUse` diagnostic hook capturing denials to JSONL will produce the data needed to choose between retry-on-fresh-spawn, dispatch-budget enforcement, or upstream escalation.

**Estimated complexity:** Quick (4 tasks, ~85 estimated minutes; a diagnostic script + settings.json hook registration + two doc edits).

**Still relevant post-PR-30?** Yes and arguably more relevant — permission denials were observed again during the Evelynn session that created this plan (2026-04-22) and nothing in PR #30 changes the harness permission-resolution path.

**Dependencies:** None blocking. T2 requires validating whether `PostToolUse` fires for subagent tool calls (open question OQ1 in plan §6) — this is empirically resolvable in T2 itself. T3 edits `agents/evelynn/CLAUDE.md` and `agents/karma/memory/karma.md` which are editable by the appropriate coordinator/agent. T4 is a deferred amend-in-place.

**Recommendation:** REVISE — add a note that T2's OQ1 (`PostToolUse` fires for subagent vs. parent tools only) must be resolved empirically first and that if `PostToolUse` only fires at the parent level, T1 and T2 need to pivot to a `SubagentStop`-style hook or per-agent frontmatter. This is a one-paragraph addendum to the plan, not a redesign.

---

## Summary Table

| # | Plan | Complexity | Relevance post-PR-30 | Recommendation |
|---|------|------------|----------------------|----------------|
| 1 | pre-lint-rename-aware | Quick | High — still a live pain | KEEP-AS-IS |
| 2 | coordinator-decision-feedback | Complex | High | REVISE (resolve OQs, annotate harness-denied tasks) |
| 3 | daily-agent-repo-audit-routine | Complex | Medium — Routines availability unverified | DEFER |
| 4 | agent-feedback-system | Complex | High — but coupled to Plans 3 & 5 | DEFER |
| 5 | retrospection-dashboard | Complex | Medium — prerequisite plans unimplemented | CLOSE (split into narrower phases) |
| 6 | subagent-permission-reliability | Quick | High | REVISE (add OQ1 pivot note) |
