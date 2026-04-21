---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
complexity: quick
orianna_gate_version: 2
tests_required: false
architecture_impact: none
tags: [plans, lifecycle, cleanup, orianna-gate]
related:
  - plans/implemented/2026-04-20-orianna-gated-plan-lifecycle.md
---

# Pre-Orianna plan archive — declutter plan phase directories

## 1. Problem & motivation

131 plans across the five phase directories (proposed, approved, in-progress,
implemented, archived) predate the Orianna-gate-v2 regime (no
orianna_gate_version field set to 2 in frontmatter). Per the grandfather
rules in architecture/plan-lifecycle.md, they never re-earn signatures and
many are already implemented or abandoned. They drown out current-regime work
in directory listings.

## 2. Decision

Relocate every pre-Orianna plan into a new top-level plans/pre-orianna/
directory, preserving the original phase as a subfolder (pre-orianna/proposed,
pre-orianna/approved, pre-orianna/in-progress, pre-orianna/implemented,
pre-orianna/archived).

### Why top-level pre-orianna (not under archived)

- The existing plan-promote-guard pre-commit hook treats any move from a
  proposed plan file into plans/archived/ as a "promotion" and requires
  either a fact-check report or a bypass trailer. Moving 73 proposed plans
  into plans/archived/pre-orianna/ would trigger that guard repeatedly.
- The existing structural linter exempts plans/archived/ but not a sibling
  like pre-orianna/. Since pre-Orianna plans often fail rule 1 (canonical
  Tasks heading) or rule 4 (path citations that no longer exist), we need
  an exemption anyway — adding it for a new sibling directory is the same
  edit either way, and a sibling directory is semantically clearer:
  grandfathered, not archived-by-policy.

### Why preserve phase subfolders

Some pre-Orianna plans are genuinely informative (implementation history);
keeping the original phase as a subfolder preserves that signal without any
body edits.

### Scope — out

- Editing plan bodies. This is a pure relocation; every git mv preserves
  history with zero content change.
- Touching plans that already carry orianna_gate_version: 2.
- Deleting anything. Plans stay in the tree; they just move.
- Concern-subdir plans under work/ or personal/ subfolders. Only top-level
  phase-dir plans are pre-Orianna; concern-subdir plans all post-date the
  gate-v2 rollout and will not match the filter.

## 3. Design

### Identification

A plan is pre-Orianna iff its frontmatter lacks `orianna_gate_version: 2` <!-- orianna: ok -->. The filter:

```sh
find plans -name '*.md' -type f -not -name '_template.md' \
  | while read f; do grep -q 'orianna_gate_version: 2' "$f" || echo "$f"; done
```

Current count by phase: 73 proposed, 0 approved, 9 in-progress, 41 implemented,
8 archived = **131 plans**.

### Move procedure

Per pre-Orianna plan at its current location:

1. mkdir -p plans/pre-orianna/<phase>/ <!-- orianna: ok -->
2. git mv the file to plans/pre-orianna/<phase>/<basename>.md <!-- orianna: ok -->

One commit captures all moves. The script is git-mv only; no body edits.

### Reference-path updates

Two hooks, `scripts/hooks/pre-commit-zz-plan-structure.sh` <!-- orianna: ok --> and its predecessor
`scripts/hooks/pre-commit-t-plan-structure.sh` <!-- orianna: ok -->, both exempt
plans/_template.md and plans/archived/. Add plans/pre-orianna/ to the same
exempt case in both hooks so staged renames of pre-Orianna plans do not fail
structural lint. This is the only hook/script change required.

The promote-guard at `scripts/hooks/pre-commit-plan-promote-guard.sh` <!-- orianna: ok --> does
NOT fire on this move — its trigger condition is a delete from
plans/proposed/*.md paired with an add in
plans/{approved,in-progress,implemented,archived}/*. Destination
plans/pre-orianna/* is none of those, so the guard is silent by design.

`scripts/plan-promote.sh` <!-- orianna: ok --> is unaffected: it only accepts source paths
from proposed, approved, or in-progress phase dirs. It will never see a
pre-orianna path.

`scripts/orianna-sign.sh` <!-- orianna: ok --> is unaffected: same reason — it operates on
the phase directories, not the archive sibling.

`architecture/plan-lifecycle.md` <!-- orianna: ok --> gets a one-paragraph note pointing
readers to plans/pre-orianna/ for grandfathered plans. No other architecture
docs reference the phase directories in a way that needs updating.

CLAUDE.md — no change needed. The File Structure table describes plans/ with
subdirs proposed, approved, in-progress, implemented, archived; adding
pre-orianna as a sixth sibling does not invalidate that description (the
list is non-exhaustive). Avoiding a CLAUDE.md edit keeps this PR tight and
low-risk.

### Lifecycle & commits

- Plan file itself (this file) goes directly to main per Rule 4 — no PR.
- Orianna-sign the plan and promote proposed → approved → in-progress →
  implemented as the work lands.
- The directory-move work goes on a branch via scripts/safe-checkout.sh,
  reviewed by Senna + Lucian via a normal PR.

## 4. Non-goals

- Body edits, frontmatter edits, or lint cleanups on any relocated plan.
- Migrating pre-Orianna plans onto the v2 gate (they stay grandfathered).
- Any changes to plan-promote, orianna-sign, or orianna-verify behavior.

## 5. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Structural linter blocks commit on staged renames | Task T2 adds a pre-orianna exemption to the linter before any moves are staged. |
| promote-guard fires on proposed-to-pre-orianna moves | Guard only matches approved/in-progress/implemented/archived as targets; pre-orianna is not in that set. Verified by reading the guard script. |
| Loss of git history on move | git mv preserves rename detection; git log --follow continues to work. |
| Concurrent plan authoring during move | Single atomic commit with all moves; window is seconds. Branch scope is plan-relocation only. |
| Plan body cites its own old path (rare) | Not fixed; bodies are untouched by policy. Readers following a stale in-plan reference hit "file not found" and can search by basename. |

## 6. Tasks

- [ ] **T1** — Identify pre-Orianna plans and write the move list to a tmp file. kind: chore. estimate_minutes: 5. Files: none (transient tmp). DoD: list contains 131 entries, each an absolute path to a plan file lacking the v2 gate field.
- [ ] **T2** — Add a pre-orianna case to the exempt branch in both plan-structure hooks (the current zz hook and the legacy t hook). kind: refactor. estimate_minutes: 10. Files: `scripts/hooks/pre-commit-zz-plan-structure.sh` (updated), `scripts/hooks/pre-commit-t-plan-structure.sh` (updated). DoD: both hooks skip pre-orianna files the same way they skip archived files; smoke-tested by staging a known-bad plan at a pre-orianna destination and confirming the hook returns 0.
- [ ] **T3** — Create pre-orianna phase subfolders and move all 131 pre-Orianna plans via git mv, preserving phase-subdir. kind: chore. estimate_minutes: 20. Files: 131 plan files renamed into plans/pre-orianna/<phase>/. DoD: git status shows 131 renames; git diff --cached --stat shows zero content changes; git log --follow on three sampled plans still traverses pre-move history.
- [ ] **T4** — Update `architecture/plan-lifecycle.md` — add a Grandfathered-plans note pointing to the pre-orianna directory. kind: docs. estimate_minutes: 5. Files: `architecture/plan-lifecycle.md` (updated). DoD: the doc's Grandfather-rules section mentions the new directory with a one-line pointer.
- [ ] **T5** — Commit, push the branch, open the PR, request Senna and Lucian review. kind: chore. estimate_minutes: 5. Files: none new. DoD: PR opened with a move summary; dual reviewers requested; no self-merge.

Total estimate: 45 minutes.

## Test plan

tests_required is false — this is a pure directory relocation with no runtime
behavior change and no new code paths. Sanity checks instead of tests:

- Move-history preservation: git log --follow on a sampled pre-orianna plan continues past the rename commit (sample three plans, one per non-empty source phase).
- No body changes: git diff --cached --stat at commit time shows 0 insertions and 0 deletions on every moved plan (pure rename).
- plan-promote unaffected: invoke it with a pre-orianna source path and confirm it rejects with the existing "plan-promote only handles plans from proposed/..." error — matching pre-change behavior.
- orianna-sign unaffected: invoke it on a pre-orianna plan; it fails with its normal "plan not in the correct source directory" error — no new code path reached.
- Hook exemption: stage a pre-orianna plan with a no-op touch and confirm the structural hook exits 0.

## Architecture impact

No new architecture concepts introduced. `architecture/plan-lifecycle.md` receives a one-paragraph note (T4) pointing readers to the `plans/pre-orianna/` directory for grandfathered plans. This is a documentation-only update; no lifecycle rules, script interfaces, or behavioral contracts change.

## Rollback

git revert on the merge commit restores all 131 plans to their original phase
directories. No state outside git changes, so no other cleanup is needed.
The plan file itself (this document) stays — it documents the decision
history.

## Open questions

- **OQ1** — Should pre-orianna eventually fold into archived when the
  grandfather population reaches zero (no more migrations pending)?
  Recommendation: defer. Revisit when the last pre-Orianna plan transitions
  to the current gate or is deleted. Until then the sibling directory is
  the lower-friction home.
