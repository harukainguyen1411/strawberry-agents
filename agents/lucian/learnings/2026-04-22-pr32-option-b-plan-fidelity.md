# PR #32 company-os — Option B vanilla Messages API plan fidelity

**Date:** 2026-04-22
**Repo:** `missmp/company-os`
**PR:** https://github.com/missmp/company-os/pull/32
**Plan:** `plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` (Swain Option B)
**Task breakdown:** `assessments/work/2026-04-22-aphelios-vanilla-api-ship-wave-refresh.md`
**Verdict:** GO (approve) with 4 drift nits
**Review report:** `assessments/work/2026-04-22-lucian-pr32-option-b-plan-fidelity.md` @ strawberry-agents `d9f99f2`

## Summary

Reviewed the 21 Option-B commits on top of the prior managed-agent waterline
(bc6b15c xfail groundwork → 35112aa). All 8 architecture invariants from the
plan hold; SYSTEM_PROMPT byte-identical (3649 chars) lift verified; wave
ordering clean with Rule 12 xfail-first on every impl commit; T.GAP PR-64
bug fixes have TDD preamble per Rule 13.

## Drift flagged (negotiable, not blocking)

1. PR body/title predate the Option-B pivot — still says "Managed Agents + MCP".
2. Wave-5 gap-fills carried off-plan (Sona's keep-signature-intact choice);
   suggest final-amend pointer on parent plan at Wave-8 cutover.
3. `test_onload_set_before_src_assignment` xfail (75a1c7c) regex rot — still
   searches for deleted S1 route pattern. Track refresh as Wave-6 follow-up.
4. MAL + MAD retirement ADRs still owed per plan §6 — correct deferral for
   Waves 1–5, but track so MAL/MAD don't sit in `implemented/` marker-less.

## Reviewer-bot access gap — persistent

`strawberry-reviewers` still cannot post formal reviews on `missmp/company-os`
(PR #57 finding still open). Sandbox also blocked the `duongntd99`-identity PR
comment fallback on this session, so the review body lives only in
`assessments/work/2026-04-22-lucian-pr32-option-b-plan-fidelity.md`. Sona /
Evelynn to escalate: grant `strawberry-reviewers` + `strawberry-reviewers-2`
collaborator on `missmp/company-os`, or Duong will need to paste the report
manually. Until then, Rule 18's distinct-reviewer requirement can't be
mechanized on work PRs.

## Process refinements

- Plan-slug citation grep is the fastest fidelity signal (20/21 here).
- SYSTEM_PROMPT byte-diff via Python regex extract is the right mechanized
  check for the "lifted, not rewritten" invariant in §5.4(a).
- When delegation prompt says "N commits ahead" and `git log main..branch`
  returns vastly more, assume the branch is a long-lived integration branch
  and scope the audit to the commits that cite the plan slug, not the raw
  count.
