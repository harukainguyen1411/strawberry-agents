# Reviewer-bot identity unblocks Rule 18 structurally

## Context

For weeks, every agent-authored PR hit `reviewDecision: REVIEW_REQUIRED` even when Senna + Lucian both "approved", because all agents (executors AND reviewers) authenticated to GitHub as the same account (`Duongntd`). GitHub treats `gh pr review --approve` from the PR-author account as self-approval and rejects it. The workaround had become "ask Duong to approve as `harukainguyen1411`" or (worse) admin-merge.

Rule 18 has two clauses: (a) non-author approval required, (b) agents must not use `--admin`. With one agent identity, those two clauses are simultaneously unsatisfiable.

## Fix

Camille's identity-gap plan (`plans/implemented/2026-04-19-pr-review-identity-gap.md`):

- New GitHub account `strawberry-reviewers`, invited as Write collaborator on `strawberry-app`
- Classic PAT minted on that account, age-encrypted at `secrets/encrypted/reviewer-github-token.age`
- `scripts/reviewer-auth.sh`: `cat <cipher> | tools/decrypt.sh --target ... --var GH_TOKEN --exec -- gh "$@"` — keeps plaintext in subprocess env only (Rule 6 compliant)
- Senna + Lucian agent defs updated: reviews MUST go through `scripts/reviewer-auth.sh gh pr review ...`
- Smoke test (throwaway PR #53, since closed): reviewDecision transitioned to APPROVED immediately

## Why it matters

This wasn't a bug — it was a design gap that social convention papered over. The moment we formalized reviewer agents (Senna, Lucian) as structural gates, they had to post reviews GitHub would count. That meant they needed an identity GitHub would accept. One account can't do both roles; two must.

## Reusable lesson

When a policy rule (like Rule 18) has two simultaneously binding clauses, check whether the current identity model can satisfy both. If every actor in the system is one principal, any "non-self" requirement collapses to "never." Solve it with a second identity scoped to the specific role, not by relaxing the rule. Relaxation trades the rule's value for convenience; a second identity preserves it.

Applies to any future policy that requires non-author review, non-signer countersign, non-approver merge, etc. If the system runs on one account, introduce the minimum number of additional accounts to satisfy the separation.

## Operational reminders for future Evelynn

- Every PR from Senna/Lucian must go through `scripts/reviewer-auth.sh`. Include it in delegation prompts to those agents.
- Agent-def caching means mid-session edits to `.claude/agents/senna.md` or `.claude/agents/lucian.md` don't take effect — either restart the session or pass explicit instructions in the delegation prompt until next spawn.
- PAT rotation: 90 days from 2026-04-19 → ~2026-07-18. Duong-calendar for day-80 reminder.
- Token leak risk: encrypted at rest, subprocess-scoped in use, never echoed. If `scripts/reviewer-auth.sh` drift introduces a `cat` of the plaintext, that's a critical regression.
- `strawberry-reviewers` must never be added to branch-protection bypass actors. It is a reviewer, not a merger.
