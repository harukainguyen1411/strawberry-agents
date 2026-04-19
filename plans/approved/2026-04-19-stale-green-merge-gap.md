---
status: approved
owner: camille
date: 2026-04-19
title: Close the stale-green merge gap on strawberry-app (ADR)
---

# Close the stale-green merge gap on strawberry-app

## Context

S58's portfolio-cascade merged five PRs in rapid sequence into `harukainguyen1411/strawberry-app:main` via `scripts/reviewer-auth.sh`. Each PR passed its required status checks against its own tree at push time. None of them were re-tested against a `main` that already contained its siblings' merges. Two semantic merge conflicts slipped through and broke `main`:

- **V0.3 vs. D-series.** `emulator-boot.test.ts` asserts `indexes: []` on `firestore.indexes.json`. A later PR in the cascade added index entries. Both PRs were green in isolation; together they are red. Viktor is currently fixing on `main`.
- **V0.10 vs. sibling fixtures.** UI tests drifted against fixtures that a sibling PR changed. Same pattern: green-in-isolation, red-post-merge.

Root cause: our required status checks fire against the PR head tree, not against a synthetic merge of the PR head with the current base. Because branch protection does not require branches to be up-to-date before merging, a PR can land with checks that were run against a stale base — "stale-green." When several such PRs land fast, the last-writer-wins collision surfaces only in post-merge CI on `main`.

### Current branch-protection state (verified 2026-04-19)

Fetched from `gh api repos/harukainguyen1411/strawberry-app/branches/main`:

```json
{
  "enabled": true,
  "required_status_checks": {
    "enforcement_level": "non_admins",
    "contexts": [
      "xfail-first check",
      "regression-test check",
      "unit-tests",
      "Playwright E2E",
      "QA report present (UI PRs)"
    ]
  }
}
```

Observed gaps (grep-verified against the live API, not inherited from the earlier `Duongntd/strawberry` branch-protection plan):

- The legacy `GET /repos/.../branches/main/protection` endpoint returns `404 Not Found`. The branch summary endpoint reports `required_status_checks` but **does not expose a `strict` flag**, and the `required_status_checks/contexts` endpoint is also 404. This is consistent with a legacy-view protection record where `strict` has not been set. No ruleset is configured (`/rulesets` returns `[]`, `/rules/branches/main` returns `[]`).
- `enforcement_level: non_admins` — admins bypass required checks.
- Repo settings: `allow_update_branch: false` (no one-click "Update branch" button surfaced in the PR UI), `delete_branch_on_merge: true`, all three merge modes enabled (`merge_commit`, `squash`, `rebase`).
- `required_pull_request_reviews` is not present on the returned payload via this endpoint view. Rule 18 enforcement (non-author approver) depends on a configuration the API surface does not confirm here. Out of scope for this ADR but flagged for a follow-up audit.

The S58 incident is therefore not a hook failure or an agent-behavior failure — every PR met every stated gate. The gate set is incomplete: nothing verifies the PR head's behavior against the actual post-merge tree.

### Constraints

- **Free tier only.** No GitHub Advanced Security, no paid Actions minutes. Solutions must fit within the public-repo / free-tier budget.
- **Mid-migration.** Portfolio-v0 cascade into `strawberry-app` is still active. A solution that halts the cascade (hard serialization with long queue waits, or gates that require every open PR to rebase) is unacceptable until the migration settles.
- **Single-repo scope.** `strawberry-app` only. `strawberry-agents` (this repo, infra/plans) is out of scope.
- **Rule 18.** No admin-bypass, no self-approval. Any remediation must keep this invariant intact and ideally strengthen it by removing the `enforcement_level: non_admins` carve-out.

### Reference — S58 stale-green incident

The cascade: V0.3, V0.4 (D-series add), V0.5, V0.10, and one further sibling merged in sequence. Each merge advanced `main`. The second, fourth, and fifth PRs' CI runs had executed on a `main` that no longer existed by the time they merged. The two collisions (V0.3 vs. D-series indexes, V0.10 vs. sibling fixtures) were structurally undetectable under the current gate set, regardless of reviewer diligence. See also `agents/evelynn/learnings/2026-04-19-stacked-pr-base-check.md` for the related (but distinct) stacked-base-ref class of merge error from S57 — that learning is about `baseRefName != main`, this ADR is about `baseRefName == main` but `baseRef.sha` stale.

---

## Options considered

### Option 1 — Turn on "Require branches to be up to date before merging" (`strict: true`)

Flip the `strict` flag inside `required_status_checks`. Effect: GitHub blocks merge until the PR branch contains the current tip of `main`. When a sibling PR lands, all other open PRs go yellow ("This branch is out-of-date with the base branch") and must either click "Update branch" (runs a merge-from-main into the PR branch) or have `main` merged in locally, which re-triggers the required checks against the post-merge tree.

**Pros.**
- Directly addresses the stale-green class: checks always run against a tree that includes current `main`.
- Zero new infrastructure — a single PATCH to the existing protection record.
- Free-tier compatible; costs exactly one extra CI run per PR per sibling merge.
- Well-understood by GitHub tooling; `allow_update_branch: true` can be enabled alongside to give the PR UI a one-click refresh button.
- Reversible in one API call.

**Cons.**
- During the cascade, every sibling merge invalidates all other open PRs' green status. With five-deep cascades this is 1+2+3+4+5 = 15 re-runs instead of 5. On a trivial unit-test matrix this is cheap; on Playwright E2E (the slowest check) it is not free.
- Encourages "merge-train thrash": whoever clicks first wins, the rest must refresh. In a solo-operator repo with agent coordination this is tolerable; still, it adds friction.
- Does not catch every semantic conflict — only those that manifest as CI failures. A conflict that only surfaces at runtime against production data is still undetectable. (This is a non-goal here; we are closing the CI-detectable sub-class.)

**What it catches for S58.** Both incidents. V0.3's emulator-boot test would have failed when V0.3 was updated to include D-series's merge, because the fixture would no longer be `[]`. V0.10's UI tests would have failed against the refreshed sibling fixtures.

### Option 2 — GitHub merge queue

Enable `merge_queue` on `main`. PRs queued for merge are batched; GitHub creates synthetic merge commits and runs required checks against the synthetic tree. PRs merge only if their synthetic-merge checks pass, in queue order.

**Pros.**
- Structurally eliminates stale-green merges: every merge is gated on a check run against the post-queue tree.
- Handles batches — if five PRs queue together, GitHub runs checks on one synthetic tree and merges them together (within batch limits).
- Strongest guarantee of the three options.

**Cons.**
- **Workflow change mid-migration.** Agents currently drive merges via `scripts/reviewer-auth.sh`. Merge-queue requires `gh pr merge --auto` semantics plus `merge_method: "merge"` or `"squash"` configured at the queue level, and changes how `mergeStateStatus` is interpreted by the merge script. This is a non-trivial agent-harness change during an active cascade.
- **Free-tier Actions minutes.** Merge queue runs an additional CI cycle per PR (the queued synthetic-merge check) on top of the existing PR checks. Playwright E2E is our slowest job; doubling its run cadence is a real cost on the free tier even for a public repo (rate limits, not billing, become the concern at high volume).
- Merge-queue CI workflows must be authored specifically to handle the `merge_group` event. Our existing workflows trigger on `pull_request` and `push`; none listen for `merge_group`. Adding the trigger is small; getting our TDD-gate job to behave correctly on `merge_group` (it asserts commit-message patterns on the PR head, not the synthetic merge) is not.
- GitHub's merge queue requires branch protection to require status checks that are reported by workflows triggered on `merge_group`. This is a duplicate-contexts problem: the PR-time required check and the queue-time required check are different contexts, and both must be satisfied. Mis-configuration leaves merges stuck.
- Overkill for the stale-green class specifically. Merge queue is designed for high-throughput repos where dozens of PRs land per day. We are nowhere near that volume.

**What it catches for S58.** Both incidents, same as Option 1.

### Option 3 — Custom pre-merge "tripwire" CI step

Add a small workflow — call it `merge-tripwire` — that runs on `pull_request` and performs a cheap, targeted check against a locally-computed merge of `PR head` onto `origin/main`. Scope limited to the specific invariants we know bite us:

1. `firestore.indexes.json` is valid JSON and parses cleanly post-merge.
2. `emulator-boot.test.ts` (and its siblings under V0.3's pattern) are consistent with `firestore.indexes.json` shape — e.g. if the test asserts `indexes: []`, fail if `firestore.indexes.json` contains indexes.
3. Any test file that references a fixture path must resolve that path post-merge.

Add `merge-tripwire` as a required status check on `main`.

**Pros.**
- Targets exactly the two failure modes S58 hit; extensible to additional invariants as we learn new ones.
- Runs once per PR, independent of cascade size. Cheap on Actions minutes.
- Does not change the merge workflow — agents keep using `scripts/reviewer-auth.sh` unchanged.
- Works even without `strict: true` because the merge-tripwire job computes the synthetic merge itself.

**Cons.**
- **Scope-limited by construction.** We catch only the invariants we code. V0.10's UI-fixture drift was a surprise; the next class of collision will also be a surprise. Tripwire becomes a graveyard of special cases.
- Authoring and maintaining the invariant checks is non-trivial. The `indexes` shape check specifically is easy; generalizing to "any test fixture post-merge consistency" is not.
- A merge-tripwire that silently passes when the invariant list is incomplete is worse than no gate — it gives a false sense of coverage.
- Still requires the underlying fix to the gate model; tripwire is a layer *on top of* the real fix, not a replacement.

**What it catches for S58.** V0.3 with a targeted check. V0.10 only if we write the specific fixture-consistency rule ahead of time, which is unlikely.

---

## Recommendation

**Option 1 — enable `strict: true` on the existing `required_status_checks` record, plus two supporting changes.** Adopt Option 3 *as a follow-up hardening layer only if specific recurring classes emerge.* Reject Option 2 for now.

### Why Option 1

- It is the minimum change that structurally closes the stale-green class. The other options either solve more than we need (Option 2) or solve less (Option 3).
- It reuses infrastructure that already exists. No new workflow files, no new contexts, no agent-harness changes.
- It is reversible in one API call if the cascade friction turns out to be worse than the staleness risk. Option 2 is not cheaply reversible — teams that enable merge queue tend to stay on it because the CI workflow triggers must be re-authored for the `merge_group` event.
- It strictly dominates Option 3 on coverage of the S58 incidents (catches both, not just one), at a cost that is bounded to one extra CI run per PR per sibling-merge.
- Free-tier compatible. The marginal cost is n(n+1)/2 CI runs across a cascade of n PRs instead of n runs; for n=5 this is 15 vs 5. Tolerable.

### Supporting changes to land in the same remediation

These are not alternatives, they are prerequisites to making Option 1 effective:

1. **Set `allow_update_branch: true` at the repo level.** This exposes the "Update branch" button in the PR UI, which in turn lets agents and humans refresh stale PRs with a single API call (`PUT /repos/.../pulls/{n}/update-branch`) instead of a local merge-push cycle. No protection-record change needed; it is a repo setting. Cost: zero.
2. **Remove the `enforcement_level: non_admins` carve-out.** Rule 18 already forbids admin-bypass at the agent layer, but the protection record still allows it at the GitHub API layer. With `strict: true` on, a non-strict admin merge re-introduces the exact failure this ADR is trying to prevent. This aligns with the earlier `plans/approved/2026-04-17-branch-protection-enforcement.md` §3 recommendation (`enforce_admins: true`) — extend it to the `strawberry-app` repo, which was out of scope for that plan.
3. **Document the cascade refresh protocol.** When a sibling PR merges, all other open PRs must be refreshed via `gh api -X PUT /repos/.../pulls/{n}/update-branch` before their re-run checks are considered authoritative. This goes into `architecture/pr-rules.md` and into Yuumi's merge-sweep delegation prompt so the next cascade is self-healing.

### Why not Option 2 *now*

Not forever — merge queue is the right answer if PR volume on `strawberry-app` grows past ~2–3 merges/day into `main` and the refresh thrash of Option 1 becomes a real bottleneck. Revisit when that threshold is crossed. Today it is a workflow-change cost we cannot afford mid-cascade and a free-tier CI-minutes cost we should not pay for a problem Option 1 already solves.

### Why not Option 3 *as the primary*

A tripwire is a detection mechanism, not a gate model. It catches the invariants we remember to encode and misses everything else. Adopting it as the primary fix would be a cheaper-seeming solution that does not actually close the class — it only narrows the specific manifestations that S58 surfaced. If we later see failure modes that Option 1 does *not* catch (e.g. runtime config collisions that are not test-detectable), then Option 3 becomes worth authoring, targeted at that specific residue.

---

## Success criteria

- `gh api repos/harukainguyen1411/strawberry-app/branches/main/protection/required_status_checks` returns a payload with `strict: true`. (If the legacy endpoint still 404s, verify via the branch summary endpoint that the `strict` field is reported on the `required_status_checks` object — this may require migrating the record to the modern view endpoint first.)
- `allow_update_branch: true` on the repo settings.
- Admin enforcement covers required status checks (`enforcement_level` ≠ `non_admins` on the status-check record, equivalent to `enforce_admins: true` in the legacy view).
- Reproduction test: open two PRs against `main` whose combined diff is red but individually green; merge one; confirm GitHub blocks the second merge with "out of date with base branch" until the PR is refreshed; confirm that after refresh, the required check re-runs against the post-merge tree and reports red.
- The CLAUDE.md Rule 18 language continues to hold — no `--admin`, no self-approval — and the protection record no longer contradicts it.

---

## Out of scope

- Merge queue. Deferred to a future ADR if PR volume warrants.
- Custom tripwire CI. Deferred; author only if a class of failure emerges that `strict` does not cover.
- Any changes to `strawberry-agents` branch protection. This ADR is scoped to `strawberry-app` per the constraint.
- Rule 18 review-requirement auditing (whether `required_pull_request_reviews.require_last_push_approval` is set, whether the non-author approver gate is actually wired on this repo). Flagged during the grep-verify step of this ADR; separate follow-up.
- Changes to `scripts/reviewer-auth.sh`. Option 1 does not require any; documenting the cascade refresh protocol is plan-level, not script-level, work.

---

## Open questions

- **Legacy view vs. modern view.** The classic `/protection` endpoint returns 404 for this repo, but the branch summary reports a partial protection payload. Before running the PATCH, confirm whether the record is (a) a modern ruleset surfaced through the legacy endpoint, (b) a legacy record in a state the API can't serialize, or (c) something installed by an older `setup-branch-protection.sh` run that needs re-creation. The implementer should start by resolving this and documenting the endpoint semantics.
- **`harukainguyen1411` collaborator permissions.** Setting `enforce_admins: true` on `strawberry-app` — the repo owner is `harukainguyen1411`, not `Duongntd`. Confirm which account holds admin rights on this repo before planning the break-glass procedure; the `Duongntd/strawberry` §3 procedure may not transfer cleanly.
- **Cascade in-flight behavior.** When `strict: true` lands, every open PR against `main` immediately goes out-of-date. The implementer should coordinate with Evelynn to either drain the current cascade first, or refresh all open PRs in one pass immediately after the PATCH. Preferred: drain first.
