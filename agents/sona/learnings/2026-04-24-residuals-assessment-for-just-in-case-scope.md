# Residuals assessment for "just in case" scope (2026-04-24)

## Context

Duong pushed back on S2 plan overengineering — the plan had accumulated scope
items that were defensive ("just in case") rather than required for the stated goal.
The items weren't wrong, but they inflated the plan and made the core work harder
to track.

## Pattern locked in

When a plan review surfaces scope items that are:
- Defensive ("just in case X happens later")
- Speculative ("this might be needed when Y")
- Adjacent-but-not-required ("while we're here, we could also...")

The correct response is NOT to remove them from consideration. It is to:

1. **Strip them from the main plan.** Keep the plan focused on the minimum required
   to achieve the stated goal.
2. **Capture them in a residuals assessment** at `assessments/work/YYYY-MM-DD-<slug>-residuals.md`.
   The assessment documents each item, the risk it addresses, and the trigger
   condition under which it becomes worth doing.

## Why it works

- Plans stay tractable and reviewable.
- Residual scope doesn't disappear — it's in an assessment that survives the session.
- The trigger conditions are explicit, so the next instance knows when to pull
  the items forward without having to reconstruct the reasoning.
- Duong gets to review a lean plan without losing the reasoning for the deferred items.

## Application

Apply to all plan authoring and plan review turns. When a Swain, Azir, or Karma
plan draft contains more than 20% scope that is defensive or speculative, surface
this pattern and propose the residuals split before Duong review.

## last_used
2026-04-24
