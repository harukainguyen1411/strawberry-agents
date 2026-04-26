---
agent: senna
date: 2026-04-25
topic: PR 66 — pre-dispatch parallel-slice doctrine review
verdict: advisory LGTM (COMMENTED, not approved — non-blocking polish)
pr: https://github.com/harukainguyen1411/strawberry-agents/pull/66
concern: personal
---

# PR 66 — pre-dispatch parallel-slice doctrine: advisory LGTM

## What the PR did

T1 added a `## Slice-for-parallelism check` gate to `_shared/coordinator-routing-check.md`
(the routing primitive shipped in PR 58). T2/T3 added matching `## Slicing` sections to
the four breakdown / test-plan agent defs (Aphelios, Kayn, Xayah, Caitlyn) introducing
the `parallel_slice_candidate: yes|no|wait-bound` per-task field. T4 ran
`sync-shared-rules.sh` to propagate the updated primitive into Evelynn + Sona. T5 was
static smoke (grep for field presence + heading presence).

T2/T3 needed fixup commits because initial placement of `## Slicing` sections was BETWEEN
two `<!-- include: -->` markers — that's the silent-discard zone of the sync script's
state machine (S4 invariant in the script header). Talon caught it; final placement is
BEFORE the first include marker (in the script's "header" mode) and is preserved.

## What I verified

- Cloned PR branch into /tmp, ran sync twice, md5 hashes identical across both runs for
  all six touched files. Sync is fully idempotent given the corrected placement.
- `parallel_slice_candidate` present exactly once in each of the four breakdown agents
  AND in both coordinator includes (post-sync).
- Only two consumers of `_shared/coordinator-routing-check.md` repo-wide: Evelynn, Sona.
  Both got the synced version. No drift consumers missed.
- Only four consumers of `_shared/breakdown.md` / `_shared/test-plan.md`: exactly the
  four breakdown agents in the PR. No drift consumers missed.

## Findings I posted

1. **Stale "two structured routing pauses" line** — primitive header still says "two"
   but there are now three structured gates. Cosmetic but a coordinator scanning
   top-down sees a count mismatch with the headings below.
2. **Three different `wait-bound` example lists** — `(test runs, deploys, external polling)`
   in Aphelios/Kayn, `(test runs, CI pipelines, external polling)` in Xayah/Caitlyn,
   `(test runs, deploys)` in the primitive itself. Suggested harmonising to a superset.
3. **Field schema not enforced — typos silently downgrade to `no`** — primitive says
   "field absent → default to `no`" but a typo (`Yes`, `wait_bound`) falls through the
   same path silently. Suggested adding "match is case-sensitive; unknown values fall
   through to the absent-field default" so the failure mode is visible.
4. **Doctrine in per-agent headers, not in `_shared/breakdown.md` / `_shared/test-plan.md`** —
   correct placement for sync-loop safety, but means future breakdown/test-plan agents
   that consume those shared rules won't pick up the field requirement automatically.
   Future-debt; flagged for a follow-up that lifts the doctrine into the shared rules
   AND adds `parallel_slice_candidate:` to the canonical `## Task line format` template.
5. **Wait-bound exception is positioned as an afterthought** — primitive's prose says
   "If BOTH yes → slice. Exception: wait-bound — do not slice." Under pressure the
   coordinator can fire on the first sentence. Suggested reordering: check wait-bound
   first, then BOTH-yes. The field-lookup section below already reorders correctly.

## Patterns / takeaways for future reviews

- **Sync-loop test for `_shared/` consumer changes is a 2-step clone + sync-twice
  routine.** Useful to keep in muscle memory. Clean clone of PR branch, snapshot md5s,
  run sync, snapshot, run sync again, compare. Stable hashes across both runs proves
  idempotency.
- **`grep -rln "include: _shared/<role>"`** is the canonical "drift consumer" check
  whenever a shared file changes. Always run it on shared-include PRs.
- **String enums in prompt-doctrine fields are a soft-typing hazard.** Without a
  validator, typos look like "absent value" to the consumer. Worth flagging on every
  similar PR.
- **"Header" placement before the first `<!-- include: -->` marker is the only safe
  zone for hand-authored prose in agent defs that consume shared rules.** Talon's S4
  invariant comment in `sync-shared-rules.sh` is the canonical source of truth for
  that.

## Identity / auth

- Concern: personal (`[concern: personal]` in dispatch).
- Auth: `scripts/reviewer-auth.sh --lane senna ...`. Verified `gh api user --jq .login`
  → `strawberry-reviewers-2` before posting.
- Posted as `--comment` (advisory LGTM), not `--approve`. Findings are wording polish
  + minor doctrine-leakage debt — none block merge, but I don't approve until at least
  finding #1 (stale "two") is corrected; that's a factual error in a primitive that
  coordinators read every dispatch.
