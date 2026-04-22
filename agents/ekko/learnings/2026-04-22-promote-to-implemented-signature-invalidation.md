# Promoting to implemented — ## Test results section invalidates prior signatures

**Date:** 2026-04-22
**Context:** Attempted to promote 2026-04-22-orianna-sign-staged-scope.md and 2026-04-20-strawberry-inbox-channel.md from in-progress to implemented after their respective PRs merged.

## The problem

The `implementation-gate-check` (in-progress→implemented) Orianna gate requires:
- `## Test results` section in the plan body (when `tests_required: true`)
- `architecture_changes: [...]` or `architecture_impact: none` + `## Architecture impact` section

Both plans were missing these. **Adding `## Test results` to the body changes the body hash**, which invalidates the `orianna_signature_approved` and `orianna_signature_in_progress` fields (they both hash the body at signing time).

## Consequence

Adding the required `## Test results` section requires a full re-sign chain (approved → in_progress → implemented) because both prior signatures become stale.

## The git history contamination problem (Plan 1 / staged-scope)

When re-signing Plan 1, I hit a deeper issue: the `orianna-verify-signature.sh` walks git log to find the commit that "introduced" the signature field. It finds commits by checking if the diff adds `+orianna_signature_approved:`.

The merge from origin/main included a "test commit + revert" pair (c87614d/c6a1743) by Duongntd that modified the signature field. The revert re-added `+orianna_signature_approved:` with Duong's author identity, which the verifier sees as the "signing commit" with wrong author — even though the legitimate Orianna signing commit exists deeper in the log.

Additionally, my own recovery commits (move plan between directories using cp+add instead of git mv) created `A` (new file) commits containing the signature field, further contaminating the git log.

## Resolution

Both plans require **Orianna-Bypass** by Duong's admin identity (`harukainguyen1411`) to promote to implemented. The bypass commit trailer is:
```
Orianna-Bypass: git-log contaminated by test commit pair (c87614d/c6a1743) and recovery commits touching signature fields; legitimate Orianna signing commits exist at 5479717 (staged-scope approved) and 0658d352/10ad3da1 (inbox-watch approved/in_progress)
```

## Current state (2026-04-22)

- `2026-04-22-orianna-sign-staged-scope.md`: at `plans/proposed/personal/`, status: proposed, no signatures. Requires re-sign chain approved → in_progress → implemented. OR Orianna-Bypass on implemented promotion.
- `2026-04-20-strawberry-inbox-channel.md`: at `plans/in-progress/2026-04-20-strawberry-inbox-channel.md`, status: in-progress, has valid approved + in_progress signatures (verified). Needs body fixes (architecture_changes + ## Test results) + then implemented sign. The body fix will invalidate signatures.

## Key lesson

**Add `## Test results` and `architecture_changes:` to plan bodies BEFORE the implemented-phase Orianna gate runs**, ideally as part of the PR that implements the plan — or at least as a body-fix commit immediately after implementation, before the Orianna-sign commit for the next hop. This avoids the hash-invalidation cascade.

Frontmatter-only changes (adding `architecture_changes:` key) do NOT affect body hash. Only body section additions affect the hash.
