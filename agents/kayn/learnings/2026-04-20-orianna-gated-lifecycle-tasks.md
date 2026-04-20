# 2026-04-20 — Orianna-gated plan lifecycle task breakdown

## What landed

- Inline `## Tasks` section appended to `plans/approved/2026-04-20-orianna-gated-plan-lifecycle.md` (commit `946e32d`, pushed to `main`).
- 33 atomic tasks across 11 phases; 8 shipped items inventoried and excluded.
- Tier map: 12 BUILDER / 8 REFACTOR / 9 TEST / 7 ERRAND.

## Key decisions

- **Inline-not-sibling.** First draft was a sibling `-tasks.md` file. Coordinator corrected mid-session: the ADR itself mandates §D3 one-plan-one-file, and that applies to this very breakdown. Deleted the sibling, folded content into the parent under a new `## Tasks` heading. This is a self-enforcing pattern — the ADR's own rule governs its task artifact.
- **Anti-duplicate rule.** Three things were already shipped before breakdown: `orianna-fact-check.sh`, its `plan-promote.sh` wire-up, and the invocation lockdown (script-only Orianna def). Breakdown has an explicit inventory table marking them SHIPPED with evidence (line numbers, commit SHAs) and a paragraph prohibiting re-creation. T6.5 is phrased "retire the call site" rather than "delete the script" to protect the reuse inside `orianna-sign.sh`.
- **Extend-not-replace for the pinned prompt.** `agents/orianna/prompts/plan-check.md` already passes plan 1 through 0/0/22 clean; T3.1 adds §D2.1 scope on top, preserving v1 claim-contract checks. Flagged in "Cross-cutting call-outs" as #3.

## Phase-ordering calls

- **T2.1 (sign.sh) has 7 dependencies** — the phase-check libs (T4.1–T4.4) + the two new prompts (T3.2, T3.3) + hash helper (T1.1). Dispatch cannot start sign.sh until all seven are green. This is the biggest serial bottleneck.
- **T6.4 must come after T9.1.** The grandfather-version branching needs demoted plans on disk to exercise against. Flagged as hard serial point.
- **T9.1 (bulk demotion) depends on T8.1 freeze being active first.** Otherwise someone could create a new `proposed/` file mid-demotion and the batch commit would be ambiguous.
- **T11.2 (freeze lift) is terminal** per §D12 — nothing in the ADR follows it.

## Open questions raised by breakdown

- **OQ-K1.** T4.3 lib placement — bundle vs separate file? Recommend bundle; flagged for Jayce at build.
- **OQ-K2.** CLAUDE.md rule slot for T10.4 — rule #19 is natural next; Duong call.
- **OQ-K3.** Does this ADR demote back to `proposed/` alongside the 55 others in T9.1? Breakdown assumes self-referential exception (it stays as the reference artifact); flagged for Duong.

## Breakdown patterns used

- **Inventory-before-tasks table.** Lists shipped deliverables with ADR ref, evidence path, and status. Prevents re-tasking already-done work. Should become standard for any breakdown produced after preliminary shipping.
- **Executor-tier assignment summary table** at the foot of the task list for at-a-glance dispatch.
- **Cross-cutting call-outs section** — #1–#7 bullet-point hints specifically addressed to Evelynn's dispatch flow (things she should know before spawning any agent).
- **Deferred/out-of-scope section** distinct from open questions — lets Duong see at a glance what this ADR does NOT cover.

## Gotchas

- Writing a sibling `-tasks.md` file was the natural default (every other Kayn breakdown this week used sibling pattern). ADR §D3 introduces the one-file rule specifically to deprecate that pattern. Next breakdown on a §D3-governed ADR must inline from the start.
- The ADR's freeze (§D12) applies to THIS breakdown's execution window: while Jayce/Viktor/Vi work through T1–T10, no new ADRs can be created. Evelynn needs to coordinate — anyone queuing a new ADR waits until T11.2 lifts.

## Commit trail

- `946e32d` — inline task breakdown folded into parent ADR
- Prior sibling-file draft was deleted pre-commit, never reached git.
