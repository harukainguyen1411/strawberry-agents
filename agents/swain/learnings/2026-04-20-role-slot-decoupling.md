# Role-slot decoupling via pointer ADRs

When one ADR references another ADR's concepts (agents, scripts, config keys), name the *role* not the *identity*. If ADR A says "Kayn breaks down the plan" and ADR B later redefines the breakdown role, A is now wrong and needs revision. If A instead says "the breakdown agent" and points at ADR B for the name-to-role map, B can evolve without breaking A.

## Applied this session

- Orianna-gated plan lifecycle ADR mentioned agent names 10+ times (Kayn, Aphelios, Caitlyn, Jayce, Viktor, Lucian, Swain).
- New taxonomy ADR introduces tier splits that rename who fills each slot.
- Revision pattern: (1) add a top-of-doc pointer note naming the taxonomy ADR as the name-mapping source; (2) replace each name with its role-slot phrase ("the backend breakdown agent", "the test-plan / audit role", "the PR fidelity reviewer"); (3) grep-verify no agent names remain; (4) signature/gating content stays identical — this is a pure label rename.

## Generalized rule

Any ADR that names an agent by identity is coupling itself to the current roster. When the roster changes (tier split, rescope, replacement), every such ADR breaks. Role-slot references + a single pointer to the taxonomy ADR is the only scalable shape.

## Corollary — pair-mate frontmatter

When a role has multiple fills (complex/normal), the agent definition itself should expose `role_slot:` and `tier:` in frontmatter so routing logic (Evelynn) can resolve without hard-coded pair tables. Make the pairing data-driven from the roster files, not hard-coded in the coordinator.

## Corollary — shared rules can't rely on loader-side includes

Claude Code's agent loader reads one `.md` file. `<!-- include: -->` comments are inert at invocation time. Shared rules between pair-mates must be physically inlined into each agent's file, with a sync script + drift-detection hook keeping them consistent with the canonical shared file. Generated `.claude/agents/*.md` fights human editability; sync-in-place preserves it.
