# PR missmp/company-os#132 r2 — D5 mirror + parity guardrail

**Date:** 2026-04-28
**Verdict:** APPROVE
**Comment:** https://github.com/missmp/company-os/pull/132#issuecomment-4329307803

## Context

r1 had filed BLOCKER B1: `agent_proxy.py` SYSTEM_PROMPT lacked D5 mirror that
`setup_agent.py` had received in `590e8891`. r2 landed two `chore:` commits:

- `04aeffe` — agent_proxy.py rules 2, 6, 7 verbatim mirror of plan §D5.
- `cb1e847` — `TestD5PromptParity` parameterized over both `SYSTEM_PROMPT`
  sources (5 assertions × 2 = 10 cases).

## Learnings

- **Mirror scope is plan-explicit, not full-rule-list.** When plan §D5 says
  "the same edits mirror into agent_proxy.py", verify the D5-specific rules
  match verbatim across both prompts; do NOT flag divergences in non-D5 rule
  framing (e.g. each module's rule 1 covers different first-call discipline)
  as drift. Read the plan's mirror clause literally.
- **Numbering gap (4 → 6) is structural fidelity to "5. (deleted)".**
  Both prompts skip rule 5 because the plan deleted it. Drift would be
  silently renumbering 6→5 in either copy. Test
  `test_validation_error_error_code_present` and the malformed_tool_input
  test enforce content; numbering gap is enforced by surrounding rule
  presence/absence.
- **Guardrail-against-landed-impl pattern doesn't need xfail-first.** Same
  precedent as PR #64 round-2 defense-in-depth gates. The parity test class
  asserts contract on already-shipped prompts (T-impl-prompt landed earlier
  in the same chain at `590e8891`); not a behavioral surface preceding
  impl. Rule 12 ordering still intact.
- **Anonymity scan blocks "Lucian" in review-body H1 too.** Composing work-
  scope reviews from scratch with role descriptors only is the safer path;
  agent name in heading triggers exit 3 even when the review is otherwise
  anonymous. Already in MEMORY but recurred — H1 is a hot spot.

## Final verdict

APPROVE; Rule 18 still requires non-author approval before merge.
