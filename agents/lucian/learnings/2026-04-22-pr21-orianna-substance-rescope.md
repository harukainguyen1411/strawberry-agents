# PR #21 — Orianna substance-vs-format rescope (approve)

Date: 2026-04-22
Repo: harukainguyen1411/strawberry-agents
Plan: plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md
Verdict: APPROVE

## Verification shortcuts that paid off

- **Plan file not in PR diff** — `gh pr diff 21 --name-only | grep substance-vs-format` returned nothing. Signature carry-forward check collapses to trivial. Same pattern as PR #19. Worth making this the first check on any plan-touching PR.
- **OQ-as-checklist review** — the delegation prompt enumerating six OQ decisions + the commit bodies citing OQ-N on each impl commit made the audit mechanical: jump to the relevant file/line, confirm the encoded semantics match Duong's pick. Took under 5 minutes once the diff was cloned.
- **xfail sentinel discipline** — Viktor's commits switched Rakan's fragile `grep` guards to stable sentinels (`rescope-drop: PA-1 PA-3 PA-4`, `contract-version`). The sentinels double as my review anchor: a single `grep -n "rescope-drop"` confirms T6 landed correctly.

## OQ-4 is the trap to watch

Swain's recommendation was (a) warn. Duong overrode to (b) drop entirely. Viktor correctly encoded drop — `plan-check.md` Step A has "NOT checked" wording, no warn path, and SA1/SA2/SA3 assert both `0 block` and `0 warn`. When a delegation prompt explicitly calls out "Duong-specific divergence from Swain," that is the highest-risk OQ to audit; implementers tend to default to the agent's recommendation.

## SC6 canary — acceptable pattern

When a bash fallback cannot model a semantic check (here: markdown section-body presence for IG-3), downgrading the test to a CANARY print with a detailed inline rationale + pointer to where the check IS enforced (LLM prompt + dedicated test script) is acceptable. The rationale must:
1. State what the check asserts.
2. State why the fallback cannot implement it without disproportionate scope.
3. Point to the layer(s) where it IS enforced.
Viktor's SC6 comment meets all three. Don't demand parity-or-xfail when the semantic is genuinely out of the fallback's lane.

## Mechanics

- Final message with full verdict + OQ table was essential; previous two sessions on this PR closed with only `/end-subagent-session lucian`, leaving Evelynn without a verdict. Memory updated (see below).
