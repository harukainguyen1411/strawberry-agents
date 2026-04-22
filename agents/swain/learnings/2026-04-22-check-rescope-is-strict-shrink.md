# Check-set rescope as strict shrink: how to preserve prior signatures

**Topic:** `agents/orianna/` check-set rescope. 2026-04-22 substance-vs-format plan.

## Context

Rescoping a promotion gate that already signs artifacts raises an obvious question: do prior signatures need to be re-verified / re-signed after the rule change? The naive answer is "yes, to be safe." The correct answer depends on whether the rescope strictly shrinks the set of block-capable checks.

## Finding

A **strict-shrink** rescope (no new block-capable checks added; some removed or demoted) preserves all prior signatures automatically. Reasoning:

1. The signature hashes only the artifact body (e.g. `scripts/orianna-hash-body.sh` hashes the plan body, not the check scripts or the claim contract).
2. A plan that passed the old gate satisfied N block-capable checks. The new gate demands N - k block-capable checks (where k ≥ 0). The plan trivially satisfies the subset.
3. Carry-forward verification scripts (`scripts/orianna-verify-signature.sh`) verify the stored hash against the current body. Unaffected by rescope.

The mental model: signatures are a cryptographic statement that "this body passed the gate as of timestamp T." If the gate at time T+1 is a strict subset of the gate at T, the statement remains true without re-verification.

## Non-shrink rescopes

If the rescope *adds* a block-capable check — even one — the logic inverts: existing plans may not satisfy the new check, so re-signing becomes necessary (or the new check must be grandfathered per-plan via a version field). The `orianna_gate_version: 2` field in plan frontmatter is exactly this escape hatch for the original 2026-04-20 gate introduction.

## What counts as "new block-capable"

- A check that promotes warn → block: **new** (would block plans that previously passed).
- A check that adds a previously-nonexistent block path: **new**.
- A check that demotes block → warn: **not new** (strict-shrink contribution).
- A check that drops entirely: **not new**.
- A check that refines classification such that fewer tokens trigger it: **not new** (strict-shrink contribution).

## When to explicitly document the shrink property

In the ADR, always include a §Grandfathering section that names the shrink property explicitly and enumerates the proof: "No file hashed into any signature changes. The rescope is strictly smaller. Therefore no re-signing." Otherwise downstream readers will ask.

## Counter-lesson

The `contract-version: N → N+1` bump is documentation metadata, NOT a signature invalidation signal. Agents (including Orianna itself) must not conflate "contract version changed" with "all signatures need re-check." Bumping the version is cheap hygiene; triggering a re-sign cycle is expensive. Keep them decoupled.
