# `<!-- include: -->` markers are build-time directives, not runtime includes

**Date:** 2026-04-25
**Session:** Evelynn db2e8cdf
**Trigger:** Senna's critical CHANGES_REQUESTED on PR #49 (coordinator deliberation primitive)

## What happened

PR #49 installed `_shared/coordinator-intent-check.md` and added `<!-- include: .claude/agents/_shared/coordinator-intent-check.md -->` markers to both `.claude/agents/evelynn.md` and `.claude/agents/sona.md`. The plan described this as wiring the primitive into both coordinator defs. Lucian APPROVED — he checked PR against plan, and the plan asserted the include mechanism worked at runtime. Senna flagged a critical defect: the `<!-- include: -->` marker is a **build-time directive** consumed by `scripts/sync-shared-rules.sh`, not a runtime include. Claude Code loads agent defs at session startup exactly as they appear on disk. The coordinator defs as shipped carried the marker but no inlined payload — the deliberation primitive would never reach runtime context.

## The failure mode

The plan asserted the mechanism worked. Lucian validated PR-against-plan (his defined scope) and approved correctly. Senna validated PR-against-system-reality and caught the defect. This is a **plan-level error that Lucian's fidelity review cannot detect by design** — Lucian checks whether the implementation matches the plan; if the plan is wrong about system reality, the implementation will faithfully reproduce the error.

Talon revised at `600876a0` by directly inlining the payload into both coordinator defs rather than relying on the marker.

## The rules

1. **`<!-- include: X -->` markers are consumed by `scripts/sync-shared-rules.sh` at commit time.** They produce an inlined copy of `X` inside the file. The file on disk after sync has the content; the marker is a maintenance aid, not a runtime directive.

2. **If you want a shared rule to be active in an agent's runtime context, it must be physically inlined into the agent def or present in a startup-chain read.**

3. **Senna's scope covers system-reality validation.** She is the reviewer most likely to catch plan-vs-reality divergences — include that expectation when writing her delegation prompt ("verify the mechanism asserted by the plan actually works as described, not just that the PR implements the plan faithfully").

4. **Lucian's scope is PR-against-plan fidelity only.** If the plan is wrong, Lucian approves a faithfully-wrong implementation. This is correct behavior for his role; the fix is a better plan, not a different reviewer.

## Related

- `agents/evelynn/learnings/2026-04-20-pair-reviews-catch-orthogonal-classes.md` — Senna and Lucian examine through genuinely different lenses; a clean Lucian pass gives no signal about Senna's concerns. This is the inverse: a clean Lucian pass + Senna CHANGES_REQUESTED is exactly the system working as designed.
