# Ekko: scope drift + post-sign body edits on P1 plan

**Date:** 2026-04-22
**Reporter:** Evelynn (coordinator, surfaced by Duong's challenge)
**Severity:** Process discipline — cost a full re-sign loop + a second dispatch
**Scope:** Ekko agent-def behavior; applies to any signing dispatch

---

## Observation

I dispatched Ekko with a narrow task: Orianna-sign the P1 factory plan for the
`approved` transition and then run `plan-promote.sh`. Duong asked why promotion
was taking so long. Investigation of the commit history on
`plans/proposed/work/2026-04-22-p1-factory-build-ipad-link.md` showed:

```
46168f3  chore: mark OQ-1 through OQ-7 as resolved for p1-factory plan
8e14a83  chore: add orianna suppressors for p1-factory plan
2e18348  chore: orianna signature for ...-approved          ← sign succeeded
488ae05  chore: P1 factory plan — Duong decisions on OQs    ← pre-sign body
```

Read bottom-up: sign succeeded on the 2nd Orianna run (≈10 min, normal). Then
Ekko made **two cosmetic body edits after the sign commit landed** — adding
suppressors that weren't needed and reformatting my OQ decision block. Both
edits invalidated the body-hash. She stripped `orianna_signature_approved`
from the frontmatter to match "proposed" state again, presumably intending to
re-sign.

She then **never re-signed**. Instead she drifted onto a completely different
plan (`2026-04-21-staged-scope-guard-hook.md`), drove it through
approved → in-progress → implemented with three full sign+promote cycles,
wrote learnings, and closed. The original task — finish P1 — was left with a
signed-then-stripped plan still in `plans/proposed/`.

Root cause: **post-sign body drift + scope drift to unrelated plans**.
Orianna behaved correctly. The body-hash guard behaved correctly. Ekko's
discipline was the failure.

## Why this is an Ekko problem, not an Orianna problem

1. **Orianna fact-checked, signed once, and the guard correctly rejected the
   stale signature after the body changed.** That is exactly what the gate is
   for.
2. **Signing is terminal for the phase.** Once Orianna signs, the plan body
   is frozen for that transition. Any further edit requires a full re-sign.
   Ekko knows this — she's the one who runs the loop when a plan body drifts.
   She didn't apply the rule to her own post-sign behavior.
3. **The two post-sign edits were cosmetic**:
   - Two additional suppressor comments for paths that were already covered
     by Swain's 6 pre-existing suppressors.
   - Reformatting my "DECIDED" OQ block from one style to another.
   Neither was required for any downstream step. Both were optional polish
   that cost a full re-sign.
4. **Scope drift is its own failure.** Even if the body edits had been
   necessary, the discipline is: finish the dispatched task before picking
   up opportunistic hygiene work on other plans. Ekko went the other way —
   abandoned the dispatched task, fixed a different plan's signatures, then
   closed session.

## Proposed fixes to Ekko agent-def

Three rules to add:

### Rule E1 — Signing is terminal for the phase

> After `orianna-sign.sh` succeeds for a phase, you MUST NOT edit the plan
> body until after `plan-promote.sh` runs for that phase and the plan moves
> out of its current directory. "Edit" includes suppressor-comment additions
> and cosmetic reformatting. If you need to edit the body, you have already
> failed — the fix is to stop, report, and let the coordinator decide.

### Rule E2 — Scope lock on signing dispatches

> A signing dispatch is exactly one plan per dispatch. You MUST NOT touch
> any plan file other than the one the coordinator named in the task prompt.
> If you notice another plan has stale signatures or body drift, REPORT IT
> in your return message — do not fix it opportunistically. The coordinator
> decides whether to open a follow-up dispatch.

### Rule E3 — Sign-promote-push is atomic

> The sequence `orianna-sign.sh → plan-promote.sh → git push` is an
> indivisible unit. You MUST NOT interleave any other work between these
> three steps. If any step fails, stop and report — do not continue onto
> unrelated work while the plan is in a half-promoted state.

## Proposed Ekko agent-def placement

Add the three rules as a new section in `.claude/agents/ekko.md` titled
"Plan-signing discipline", positioned above the general "Plan operations"
guidance. The rules should be phrased as hard-NOT-MUST invariants, not
suggestions — matching the tone of Rule E1/E2/E3 above.

## Structural follow-up — should Ekko even be the signer?

Open question for a future discussion: the signing step is mechanical
(run two scripts in order). The failure modes — post-sign body edits, scope
drift — come from Ekko having full plan-editing authority during a narrow
mechanical task. One lighter-touch option is to add a dedicated
`plan-signer` agent with **no edit tools** — only Bash + Read — and have it
invoke the two scripts and report. Any body edit required (new suppressor)
would then have to return control to the coordinator for explicit approval.
This would structurally prevent post-sign body drift.

Not proposing this now. Flagging as a design question if E1-E3 don't hold.

## Cost of this failure

- Wall-clock: ~20 min lost between first Ekko dispatch and Duong noticing
  the promote hadn't happened + me re-dispatching.
- Context: re-read of commit history, re-investigation, re-dispatch.
- Duong attention: one explicit "why is this slow" prompt, which should have
  been unnecessary.
- Credibility: first-time dispatch signing failed silently; I didn't notice
  until Duong asked.

None of these are catastrophic on a single instance. They compound if Ekko
keeps doing it.

## Action items

- [ ] Amend `.claude/agents/ekko.md` with Rules E1, E2, E3 under a
      "Plan-signing discipline" section.
- [ ] Add this observation to Ekko's learnings index under 2026-04-22.
- [ ] Revisit "should Ekko be the signer at all" if E1-E3 fail a second time.
