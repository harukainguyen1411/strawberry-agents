# Coordinator routing primitive

This include installs three structured routing pauses before every Agent dispatch.
Sourced by: Evelynn, Sona.

## Pre-dispatch routing block

Before any `Agent` tool call where a plan path is cited or implied, emit a 4-line block internally before proceeding. The block is not output to Duong — it is the coordinator's internal routing gate.

1. **Plan author** — what is the upstream plan's `owner:` field? (If no plan and the task is ad-hoc, this block is exempt — skip it.)
2. **Required impl-set** — given that owner, look up the row in `architecture/agent-network-v1/routing.md` §2 and state the full required set.
3. **Lane check (Error 1 shape)** — is the agent I am about to dispatch in that impl-set? If no, stop — pick from the correct set before proceeding.
4. **Pair-set completeness check (Error 2 shape)** — does the impl-set include a test-impl pair-mate (`rakan` for complex, `vi` for normal)? If yes, has that pair-mate's xfail commit already landed on the target branch? If no, dispatch the test-impl pair-mate first.

## "This dispatch feels obvious" smell

Pattern-match speed is not a license to skip the routing block. The canonical failure mode: a task surface that "feels small" (Error 1 — Talon dispatched on a Swain plan) or "the builder lane is right so we're fine" (Error 2 — Viktor dispatched without Rakan's xfail commit). Both errors happened in the same session. The routing block catches both shapes; skipping it for "obvious" dispatches is where the errors live.

When the dispatch feels obvious, that is the signal to run the block anyway, not the signal to skip it.

## Slice-for-parallelism check

Before dispatching any task estimated above 30 minutes (or flagged complex), ask:

1. Does this task take longer than 30 minutes (per breakdown estimate)?
2. Can this task be broken into meaningful parallel streams (independent work units, low merge friction)?

Exception: long-but-simple wait-bound tasks (test runs, deploys, external polling) — do not slice regardless of duration. Otherwise: if BOTH yes → slice and dispatch parallel.

When a breakdown task entry is available, read its `parallel_slice_candidate` field as the primary hint:
- `yes` — slice unless Duong has directed otherwise
- `no` — dispatch as single stream
- `wait-bound` — do not slice; dispatch as single stream regardless of duration
- field absent — default to `no` (fail-soft, backward-compatible)

Valid values: exactly `yes`, `no`, or `wait-bound` (lowercase, hyphen). Typos (e.g. `Yes`, `wait_bound`) silently treat as `no` — fail-soft, not fail-loud.

## Read-only / status-ping dispatches exempt

Skarner (read-only excavation), Yuumi (inbox FYI), Lissandra (memory consolidation) — no plan in scope, no routing block required.

Single-lane agents (Ekko, Senna, Lucian, Akali) and `tier: quick` plans (Karma-authored, `{talon}` impl-set) still require the routing block — those are exactly where Error 1 happened. No carve-out for "looks small."
