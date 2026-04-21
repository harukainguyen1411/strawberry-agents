# D1A inline triggers body-hash invalidation — the recovery dance

**Date:** 2026-04-21
**Source:** This session — inbox plan and memory-consolidation ADR inline under D1A ruling

## What happened

The D1A architectural ruling required complex-track plans to stay single-file. Aphelios breakdowns and Xayah test plans must be inlined into the parent ADR body. When those sections were inlined, the plan body hash changed — invalidating every prior Orianna signature (which binds to the body hash at sign time).

Both plans required a recovery dance:
1. Remove the stale approved signature from the file
2. `git commit` the removal
3. Demote the plan back to `proposed/`
4. Re-run `orianna-sign.sh` at the `proposed` phase
5. `git commit` the new proposed-phase signature
6. Re-run `plan-promote.sh` to move to `approved/`
7. `orianna-sign.sh` again at the `approved` phase
8. `git commit` the approved-phase signature

This took multiple rounds due to Orianna block findings in the newly inlined content (forward self-refs, cross-repo paths, bare filenames). Each block required an amendment + re-sign at that phase.

## The rule

**Inline content is a body-change.** Any structural change to the plan body (adding sections, renaming headings, inlining external documents) after a signing ceremony invalidates that ceremony and all subsequent gates that depended on it.

Do not inline until signatures are absolutely necessary — or accept that the recovery dance is the cost.

Extends `2026-04-21-sign-plans-before-adding-body-sections.md`: that learning covers adding empty placeholders. This learning covers the larger case: inlining substantial external content mid-lifecycle.

## Runbook for the recovery dance

```
1. scripts/orianna-remove-signature.sh <plan> <phase>   # if exists
2. git commit "chore: remove stale <phase> signature for re-sign"
3. git mv <plan-at-approved> <plan-at-proposed>; update status: in plan YAML; git commit "chore: demote <plan> to proposed for re-sign after body change"
4. scripts/orianna-sign.sh <plan> proposed
5. git commit "chore: orianna signature for <plan>-proposed"
6. scripts/plan-promote.sh <plan>    # proposed → approved; re-signs approved gate
7. git commit (plan-promote.sh handles this)
```

If Orianna returns blocks on the newly inlined content, fix them, commit amendments, then restart from step 4.

## Cost

Each round costs ~1 Orianna budget unit and one agent-execution cycle. With two plans today, the total overhead was roughly 8 commits and 4 Orianna invocations for remediation alone.
