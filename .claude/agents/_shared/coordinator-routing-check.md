# Coordinator routing primitive

This include installs two structured routing pauses before every Agent dispatch.
Sourced by: Evelynn, Sona.

## Pre-dispatch routing block

Before any `Agent` tool call where a plan path is cited or implied, emit a 4-line block internally before proceeding. The block is not output to Duong — it is the coordinator's internal routing gate.

1. **Plan author** — what is the upstream plan's `owner:` field? (If no plan and the task is ad-hoc, this block is exempt — skip it.)
2. **Required impl-set** — given that owner, look up the row in `architecture/agent-routing.md` §2 and state the full required set.
3. **Lane check (Error 1 shape)** — is the agent I am about to dispatch in that impl-set? If no, stop — pick from the correct set before proceeding.
4. **Pair-set completeness check (Error 2 shape)** — does the impl-set include a test-impl pair-mate (`rakan` for complex, `vi` for normal)? If yes, has that pair-mate's xfail commit already landed on the target branch? If no, dispatch the test-impl pair-mate first.

## "This dispatch feels obvious" smell

Pattern-match speed is not a license to skip the routing block. The canonical failure mode: a task surface that "feels small" (Error 1 — Talon dispatched on a Swain plan) or "the builder lane is right so we're fine" (Error 2 — Viktor dispatched without Rakan's xfail commit). Both errors happened in the same session. The routing block catches both shapes; skipping it for "obvious" dispatches is where the errors live.

When the dispatch feels obvious, that is the signal to run the block anyway, not the signal to skip it.

## Read-only / status-ping dispatches exempt

Skarner (read-only excavation), Yuumi (inbox FYI), Lissandra (memory consolidation) — no plan in scope, no routing block required.

Single-lane agents (Ekko, Senna, Lucian, Akali) and `tier: quick` plans (Karma-authored, `{talon}` impl-set) still require the routing block — those are exactly where Error 1 happened. No carve-out for "looks small."
