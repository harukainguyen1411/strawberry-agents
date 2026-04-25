# Gate bypass on "surgical" infra commits causes silent cross-component regressions

**Date:** 2026-04-25
**Session:** Evelynn resumed (post-/exit reopen)
**Trigger:** Inbox watcher silently broken after env-hygiene fix

## What happened

Earlier in this session I diagnosed the literal-sentinel SessionStart hook bug and shipped the fix via Yuumi (`b6321bcd`) — surgical, three-line script edit, direct to main, no PR. That part was fine.

Then I observed a follow-on issue: `STRAWBERRY_AGENT=sona` env var leaked from one of Yuumi's verification commands into the parent shell, mis-pinning the next resumed Evelynn session as Sona. I dispatched Yuumi again with a "small env-hygiene fix" — replace `export VAR=val; exec claude` with `exec env VAR=val claude` in the launchers. Shipped as `240bd394`, direct to main, no PR.

The fix worked for the env-leak surface. But it silently broke the inbox watcher: `scripts/hooks/inbox-watch.sh` reads identity from `STRAWBERRY_AGENT` / `CLAUDE_AGENT_NAME`, and Monitor spawns the watcher as a bash subprocess that does NOT inherit `exec env`-set vars. Watcher fails identity resolution → exits 0 silently (per its noisy-monitor guard) → Monitor stream closes → coordinator gets zero inbox events.

Duong surfaced the regression with "why is it so hard to start a script which should have been a routine??" — only after I'd tried and failed to arm the watcher in this resumed session.

## The mistake

I framed the env-hygiene fix as "surgical" and "no plan, no Karma, no ceremony — Rule 19 lets a 3-line script edit go direct under `chore:`." That framing was wrong on two counts:

1. **The diff was 3 lines but the blast radius wasn't.** Replacing `export` with `exec env` changes how identity propagates to every child process spawned in the claude session — that includes the inbox-watch Monitor target, any future hook subprocess, and any test harness. None of that was reasoned through before shipping.
2. **The gate chain exists precisely to catch this class of bug.** Karma writes the plan and surfaces the coupling. Senna reviews for code quality. Lucian reviews for plan/ADR fidelity. Talon's xfail-first TDD step would have made me write a test for "Monitor-spawned watcher resolves identity correctly," which would have failed before the implementation landed and forced a redesign.

The "small enough to ship direct" framing is a trap when the change is invisible-but-cross-component.

## Heuristic going forward

A change is genuinely "surgical" only if all three hold:

1. **Single component, single concern.** Touches one file or one tightly-bound config. Not "three launcher files + a comment edit + a Windows audit" — that's already four surfaces.
2. **No cross-process semantics.** Nothing about env vars, signals, file descriptors, or working directories. Those propagate invisibly and break things downstream.
3. **Existing test would have caught the regression.** If you can't point to a test that already covers the failure mode, the change isn't surgical — it's untested.

If any of those fail, run it through Karma quick-lane. Quick-lane has the same gates as the standard chain (Orianna → Talon TDD → Senna+Lucian review), just collapsed roles. The ceremony is cheap; silent regressions are not.

## Specifically retired framing

- ❌ "It's just a 3-line edit, ship direct."
- ❌ "Rule 19 lets agent-infra changes go direct under `chore:`." (True for the *commit-prefix* rule. Not a license to skip review.)
- ❌ "Yuumi can do this surgically."

The Yuumi/Ekko direct-execution path is for trivial mechanical tasks (file moves, doc edits, single-line typo fixes). Anything that changes runtime semantics — even one line — goes through Karma.

## Action

- Reverted `240bd394`.
- Karma quick-lane plan in flight covering env-hygiene AND watcher-identity-propagation as a coupled change with explicit regression tests for the failure modes that surfaced.
- This learning filed so the heuristic is durable.

## Related

- `agents/evelynn/learnings/2026-04-20-band-aid-scope-trap.md` — sibling failure mode (scoping a fix to first symptom rather than systemic rule). Gate-bypass is a different pattern: not scope-narrow, but process-narrow.
- `agents/evelynn/learnings/2026-04-20-rule-enforcement-needs-multiple-layers.md` — same lesson at a different level: high-stakes rules need enforcement at every surface where violation can occur. Here the rule is "review gates exist for invisible cross-component coupling," and the surface I bypassed was the review itself.
