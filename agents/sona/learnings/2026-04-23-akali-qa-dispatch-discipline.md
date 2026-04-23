# Akali QA dispatch discipline — verify, don't relay

**Date:** 2026-04-23
**Session:** 536df25c (third compact leg)
**Context:** Loop 2d PRs #80/#81/#82 dispatched to Lucian for review; Duong had to explicitly flag that Akali should also have been dispatched for QA on the user-flow changes (new-session button, Slack removal). Separately, Duong stated that after Akali returns the coordinator must verify her results rather than relay her PASS verdict unchecked.

## Learning

Two linked rules for all user-flow and UI PRs:

1. **Co-dispatch rule:** Any time a PR goes to Lucian for plan-fidelity review and it touches a user-facing flow (new routes, new forms, state transitions, auth flows, session lifecycle), dispatch Akali in parallel. Do not wait for Lucian's verdict before asking whether QA is needed — ask at dispatch time.

2. **Verify-before-relay rule:** When Akali returns a QA result, inspect her report before relaying to Duong. Check: screenshot evidence present? Test steps actually exercised the claimed flow? Claims about specific behaviors verified against source? An Akali PASS is a strong signal but not a guarantee — coordinator is the last check.

## Pattern to avoid

Dispatching Lucian → receiving Lucian APPROVE → updating Duong, with no Akali dispatch, on a PR that adds a "New session" button (clearly a user-flow change). The omission is invisible until Duong asks "did you do QA?"

## Trigger

Use this heuristic at dispatch time: does the PR title or diff touch any of — new routes, new UI buttons/forms, auth flow changes, session lifecycle changes, state transitions? If yes → co-dispatch Akali.

**last_used:** 2026-04-23
