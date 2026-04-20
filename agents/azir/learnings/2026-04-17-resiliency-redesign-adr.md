# Resiliency Redesign ADR — gotchas + process notes

## Trigger pattern: Duong says "stop whack-a-mole"

When the user is frustrated with repeated surface-level fixes on the same bug class, the right response is NOT another fix. Look for the shared structural root. Today: agent config drift + UI dedup + config sprawl all trace back to "no single source of truth" as a pattern. ADR tackled the root, not the next symptom.

## AI-native effort estimates

Pre-ADR draft used "~2.5 weeks" for a 3-part redesign. Duong collapsed it to "~90 minutes" and he was right. When we have AI-native execution + TDD + existing patterns + tight scope, the multiplier is 10–50x, not the 2x of a human contractor on overtime. Future ADRs: default to hours/minutes for well-scoped Parts; only use days for genuinely new patterns (new protocols, new infra types).

## Hard-cut is the default when product isn't live

Duong explicitly rejected feature flags across Parts 1–3. Product not live → hard cut → revert commit is the rollback. Feature flags are for live-traffic regression safety; they add complexity every other time. Stop defaulting to them.

## Handoff pattern: embed the task-list-delta in the ADR

Step 2 ADR handed Kayn a task-amendment list inline. Resiliency ADR hands Kayn a three-Pass outline with per-Pass TDD pairs and owners inline. Both worked because Kayn reads the ADR, not a separate brief. Pattern: if the ADR changes affect existing tasks, spell out the amendments by task ID in Handoff Notes. If the ADR creates new tasks, spell out the Pass/Track/Layer structure with owners. Either way, the ADR is the brief.

## Edit tool requires Read after context reset

After a system reminder interrupts mid-edit-chain, Edit fails with "File has not been read yet" even if I read the file earlier in the same turn. Solution: Re-Read first. Cost ~1 tool round-trip; cheap.

## Frontmatter fragility

`status: draft` at line 3 of the ADR got mangled when a late edit accidentally struck the opening `---` fence. Ended up as `## status: draft` — a heading, not YAML frontmatter. Caught by a targeted Grep, fixed with a clean Edit. Lesson: when editing near frontmatter, grep for `^status:` or `^owner:` afterward to confirm the fences are intact. The plan-mode protocol (frontmatter with status + owner) is important enough to verify.

## Decision provenance matters in the ADR

Kept Q3 rev 1 → rev 2 reversal visible in the Step 2 ADR ("Why not a new DS_MCP_INVOKER_TOKEN (Q3 rev 1, reversed)"). Same pattern in Resiliency ADR: "prior draft's 2.5-week estimate reflected old-world developer cadence." Reviewers reading the task list later won't be confused by the git/task history showing `DS_MCP_INVOKER_TOKEN` — the ADR tells them that was rev 1 and why it was reversed. Always leave the reversal explanation in place; delete only the obsolete instructions, not the rationale.
