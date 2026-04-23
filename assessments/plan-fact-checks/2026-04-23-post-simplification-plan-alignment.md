---
date: 2026-04-23
author: ekko
concern: personal
subject: Bulk audit — proposed + approved personal plans vs simplified Orianna gate (PR #30)
---

# Post-simplification plan alignment audit

Audited 13 personal plans (10 proposed, 3 approved) against the 5 alignment criteria
introduced by PR #30 (`orianna-gate-simplification`, currently in-flight on branch
`orianna-gate-simplification`).

Audit is static / read-only. `orianna-sign.sh` was not invoked.

---

## 1. plans/proposed/personal/2026-04-21-agent-feedback-system.md

- **File:** plans/proposed/personal/2026-04-21-agent-feedback-system.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** false
  - Body justification present: yes (line 665 explains the opt-out for this doc+config+shell plan)
- **test task present:** N/A (tests_required: false)
- **delete-semantics risk:** minor — lines 594 ("safe to delete if desired") and 598 ("Only remove the shared-rules include") both refer to cleanup of _feedback/_ historical artifacts and a shared-rules stanza. These are optional and the wording is advisory, not imperative. The plan's core is additive. No `git rm` on lifecycle artifacts.
- **overlap with PR #30:** none — this plan builds a coordinator decision-feedback corpus and preference-learning loop. Orthogonal to Orianna gate mechanics.
- **Recommendation:** keep as-is. No frontmatter bump needed (already v2). No test task required (tests_required: false, justified). Minor delete references are advisory/rollback-only.

---

## 2. plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md

- **File:** plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — T1, T3, T5 all begin with "Write xfail tests …" (matching `^(write|add|create|update) .* test` regex) and are explicitly TDD xfail tasks committed before their implementations.
- **delete-semantics risk:** none — no delete, rm, or git rm calls in task bodies. Rollback section uses revert-then-restore semantics only.
- **overlap with PR #30:** none — this plan is a coordinator preference-learning system (decision logs, preferences.md, axes.md). Completely independent of Orianna gate mechanics.
- **Recommendation:** keep as-is.

---

## 3. plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md

- **File:** plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — T1 is "Write xfail tests for the delta-algorithm state machine" (title begins with "Write … test"). T3 and T6a are also explicit xfail-first test tasks.
- **delete-semantics risk:** minor — lines 686–687 are in the Rollback section: "Additionally delete .claude/skills/audit/ + scripts/audit-*" and "Delete the Claude Code Web Routine entry + delete assessments/audits/ + architecture/audit-routine.md". These are rollback-only instructions describing how to undo, not the plan's primary execution path. The plan's normal path is additive. No risk of accidentally destroying lifecycle artifacts during forward execution.
- **overlap with PR #30:** none — daily audit routine is about repo health observations (duplication, broken paths, orphaned plans). Not Orianna gate mechanics.
- **Recommendation:** keep as-is.

---

## 4. plans/proposed/personal/2026-04-21-orianna-work-repo-routing.md

- **File:** plans/proposed/personal/2026-04-21-orianna-work-repo-routing.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — Task 1 is explicitly `kind: test` (line 25: "kind: test (xfail, committed first per Rule 12)"). DoD lists concrete assertions.
- **delete-semantics risk:** none detected.
- **overlap with PR #30:** none — this plan adds concern-aware path routing to scripts/fact-check-plan.sh so work-concern plans can cite paths in the company-os repo. PR #30 retires fact-check-plan.sh entirely (archived under scripts/_archive/v1-orianna-gate/). This creates a **significant overlap**: if PR #30 merges, the entire target file (scripts/fact-check-plan.sh) and its test suite (scripts/test-fact-check-work-concern-routing.sh) are archived as v1 artifacts. The ## Test results section (line 68) shows this plan was already implemented (PR #20 equivalent: "8 passed, 0 failed, run 2026-04-22") — the implementation was merged but the plan was never promoted. Status is still `proposed`.
- **Recommendation:** should be closed as obsoleted by PR #30. The routing was already implemented (test results present), and PR #30 removes the file being patched. If the work-concern routing concept needs to carry forward into the v2 Orianna agent prompt, that should be a follow-up task on PR #30 — not this plan.

---

## 5. plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md

- **File:** plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — T1 is "Write xfail regression tests for three rename scenarios" with `kind: test` implied by the task (the title begins with "Write … tests").
- **delete-semantics risk:** none detected.
- **overlap with PR #30:** partial — this plan fixes scripts/hooks/pre-commit-zz-plan-structure.sh for rename-awareness. PR #30 does not explicitly archive this hook (it archives orianna-sign.sh, plan-promote.sh, and the signature-guard hooks). The plan-structure hook is orthogonal to gate mechanics. However, PR #30's T3 ("one-shot plan cleanup sweep") could interact with this hook during the sweep commit. No direct obsolescence.
- **Recommendation:** keep as-is. The sign-race-unblock note in memory (this plan's promotion was blocked by concurrent-staging race) is historical context, not a current blocker. The plan itself is well-formed.

---

## 6. plans/proposed/personal/2026-04-21-retrospection-dashboard.md

- **File:** plans/proposed/personal/2026-04-21-retrospection-dashboard.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — T2 is "Write xfail test for the ingestor's buildRetroJson function" (title begins with "Write … test"). T6 is "Add xfail tests for each of the ten named queries." T12 is "Write the capture file schema doc + xfail test…". Multiple write/add xfail test tasks present.
- **delete-semantics risk:** minor — line 339 (Rollback section): "Remove the sibling repo + delete agents/retro/ from strawberry-agents." This is the rollback path, not the forward execution path. No risk to lifecycle artifacts.
- **overlap with PR #30:** none — new sibling repo, UI dashboard. Fully independent.
- **Recommendation:** keep as-is.

---

## 7. plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md

- **File:** plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** false
- **test task present:** N/A (tests_required: false)
- **delete-semantics risk:** none detected.
- **overlap with PR #30:** significant — this plan adopts STAGED_SCOPE across the agent fleet (Yuumi, Ekko, Syndra, Talon, Viktor, Jayce). The STAGED_SCOPE mechanism was introduced by plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md and is specific to scripts/orianna-sign.sh and scripts/plan-promote.sh. PR #30 archives both scripts entirely (T2: "Move scripts/orianna-sign.sh, scripts/plan-promote.sh … to scripts/_archive/v1-orianna-gate/"). If PR #30 merges, STAGED_SCOPE in these scripts becomes meaningless because the scripts no longer exist. The agent definitions would reference a pattern that applies to retired tooling. The one survivor is the pre-commit-staged-scope-guard.sh hook itself (not archived by PR #30) — that hook continues to enforce STAGED_SCOPE for general git commits, which is independently valuable. However, the plan's stated rationale is specifically about orianna-sign.sh race prevention.
- **Recommendation:** should be revised. The general STAGED_SCOPE discipline for agent git commits (preventing bulk-stage accidents) is still valuable even post-PR #30. The plan should be reframed to drop the orianna-sign.sh-specific rationale and focus purely on the general hook compliance. If that reframing is not worth it, close as mostly obsoleted by PR #30.

---

## 8. plans/proposed/personal/2026-04-22-orianna-rescope-canary.md

- **File:** plans/proposed/personal/2026-04-22-orianna-rescope-canary.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** false
- **test task present:** N/A (tests_required: false)
- **delete-semantics risk:** none — read-only canary, no code changes.
- **overlap with PR #30:** significant — this is a T11 canary fixture for the substance-vs-format rescope ADR (plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md, which is itself a precursor to PR #30). Its purpose is to verify zero BLOCK findings when the rescope lands. PR #30 goes further: it retires the entire scripts/fact-check-plan.sh gate and replaces Orianna with a callable agent. The canary's success criterion ("zero block findings on first scripts/orianna-sign.sh run after the rescope") is about the v1 gate behavior. Once PR #30 merges, there is no orianna-sign.sh to run; the canary is permanently moot. The three internal-prefix claims in §3 (agents/orianna/claim-contract.md, scripts/fact-check-plan.sh, agents/orianna/prompts/plan-check.md) also point to files that PR #30 either archives or replaces.
- **Recommendation:** should be closed as obsoleted by PR #30. The canary served its diagnostic purpose for the substance-vs-format rescope; the simplified gate makes it irrelevant.

---

## 9. plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md

- **File:** plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — T1 is "Add xfail test exercising the concurrent-staging race" (`kind: test` implied; the T1 section heading says "Add xfail test"). T1 is a dedicated test task.
- **delete-semantics risk:** none.
- **overlap with PR #30:** significant — this plan adds STAGED_SCOPE to scripts/orianna-sign.sh and scripts/plan-promote.sh. The ## Test results section (line 150–152) shows the plan was already implemented: "PR #20 (squash e7189281) merged 2026-04-22. All required checks passed." The status field still says `proposed`, which is inconsistent with the implementation evidence. PR #30 archives both scripts this plan patched. The plan is both already-implemented and about-to-be-obsoleted.
- **Recommendation:** should be closed as obsoleted by PR #30. The plan was effectively implemented (PR #20 merged), but the file was never promoted. Recommend archiving this plan (status: archived) as it describes a v1-gate mechanism that PR #30 retires. Do not promote it through the normal v2 gate chain — that would be wasteful.

---

## 10. plans/proposed/personal/2026-04-22-subagent-permission-reliability.md

- **File:** plans/proposed/personal/2026-04-22-subagent-permission-reliability.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** no — task kinds are: T1=script, T2=config, T3=doc, T4=plan-followup. The test plan section (§4) describes an "xfail-first test" but it is described inline as part of the T1 DoD narrative ("xfail-first test tests/hooks/test_subagent_denial_probe.sh"), not as a separate task with `kind: test`. There is no standalone task with `kind: test` or a title matching `^(write|add|create|update) .* test`. **This plan fails the test-task check for the simplified gate.**
- **delete-semantics risk:** none detected.
- **overlap with PR #30:** none — subagent permission-denial diagnostics are orthogonal to Orianna gate mechanics.
- **Recommendation:** needs test task added. Add a T0 task with `kind: test` and title "Write xfail test for subagent-denial-probe.sh" before T1 (or fold into T1 by adding `kind: test` and changing T1's title to begin with "Write").

---

## 11. plans/approved/personal/2026-04-20-plan-structure-prelint.md

- **File:** plans/approved/personal/2026-04-20-plan-structure-prelint.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — T3 is "Write xfail test then implement scripts/hooks/pre-commit-plan-structure.sh" (title begins with "Write … test"). The xfail test is committed first per Rule 12.
- **delete-semantics risk:** none detected.
- **overlap with PR #30:** partial — this plan factors deterministic structural checks into scripts/_lib_plan_structure.sh, which is sourced by scripts/hooks/pre-commit-zz-plan-structure.sh. PR #30 archives scripts/plan-promote.sh, scripts/orianna-sign.sh, and the signature guard hooks — but not the plan-structure hook or its lib. The plan-structure hook is orthogonal to gate mechanics and survives PR #30. No obsolescence, but the `related:` field points to `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md` which has since moved to `plans/implemented/personal/`. That path reference is stale.
- **Recommendation:** keep as-is from a content standpoint. The stale related-path (`plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md`) is cosmetic and does not affect gate behavior. If the plan is promoted to in-progress during PR #30's lifetime, the path would need a suppressor.

---

## 12. plans/approved/personal/2026-04-21-plan-prelint-shift-left.md

- **File:** plans/approved/personal/2026-04-21-plan-prelint-shift-left.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** true
- **test task present:** yes — T1 is "Write regression tests (xfail-first per Rule 12). kind: test." Both the `kind: test` token and the "Write" verb are present.
- **delete-semantics risk:** none detected.
- **overlap with PR #30:** partial — this plan extends scripts/hooks/pre-commit-t-plan-structure.sh (the legacy hook). PR #30 does not archive this hook. The plan is safe from obsolescence by PR #30, but note that `pre-commit-t-plan-structure.sh` and `pre-commit-zz-plan-structure.sh` are two different scripts — this plan updates the legacy one. The `related:` field links to the approved version of plan-structure-prelint.md, which is fine.
- **Recommendation:** keep as-is.

---

## 13. plans/approved/personal/2026-04-21-pre-orianna-plan-archive.md

- **File:** plans/approved/personal/2026-04-21-pre-orianna-plan-archive.md
- **orianna_gate_version:** v2 (present)
- **tests_required:** false
- **test task present:** N/A (tests_required: false)
- **delete-semantics risk:** none — this plan uses `git mv` (line 83) to relocate pre-Orianna plans to `plans/pre-orianna/`. The plan explicitly notes (line 96) that the authoring-freeze hook does NOT fire on this move. Pure relocation, no deletion of lifecycle artifacts.
- **overlap with PR #30:** partial — PR #30's T3 ("one-shot plan cleanup sweep") strips `orianna_gate_version` and `Orianna-Signature` blocks from current plans via a sweep script. This plan moves legacy plans to `plans/pre-orianna/`. They are complementary: this plan reduces directory clutter first; PR #30's sweep handles metadata cleanup. No conflict, but if both run concurrently, the sweep may need to include `plans/pre-orianna/**` in its grep scope.
- **Recommendation:** keep as-is.

---

## Executive Summary

9 of 13 plans are aligned with the simplified Orianna gate as-is. 1 needs a test task added (medium effort): `subagent-permission-reliability` has `tests_required: true` but no standalone `kind: test` task. 3 may be obsoleted by PR #30 (decide with Duong): `orianna-work-repo-routing` (already implemented, targets an archived script), `orianna-rescope-canary` (diagnostic canary whose success condition no longer applies post-PR #30), and `orianna-sign-staged-scope` (already implemented per PR #20, targets archived scripts). A 4th plan — `agent-staged-scope-adoption` — has significant overlap with PR #30 and should be revised or closed depending on whether the general STAGED_SCOPE agent discipline (independent of orianna-sign.sh) warrants a standalone plan. All 13 plans carry `orianna_gate_version: 2`. None have suppression-marker gaps requiring immediate attention for the plans that are staying active.
