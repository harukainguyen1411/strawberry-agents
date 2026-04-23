---
status: approved
concern: personal
owner: karma
created: 2026-04-21
complexity: quick
tests_required: false
architecture_impact: none
tags: [plans, lifecycle, cleanup, orianna-gate]
related:
  - plans/implemented/personal/2026-04-23-plan-lifecycle-physical-guard.md
  - architecture/plan-lifecycle.md
---

# Pre-Orianna plan archive — declutter plan phase directories

## 1. Problem & motivation

131 plans across the five phase directories (proposed, approved, in-progress,
implemented, archived) predate the Orianna-gate regime (no `orianna_gate_version: 2`
field in frontmatter). Per the grandfather rules in
`architecture/plan-lifecycle.md`, they never re-earn signatures and many are
already implemented or abandoned. They drown out current-regime work in
directory listings.

## 2. Decision

Relocate every pre-Orianna plan into a new top-level `plans/pre-orianna/` <!-- orianna: ok -- directory/glob path, not a file -->
directory, preserving the original phase as a subfolder — subdirectory names <!-- orianna: ok -- prose names, paths are under plans/pre-orianna/ -->
`pre-orianna/proposed`, `pre-orianna/approved`, `pre-orianna/in-progress`, <!-- orianna: ok -- subdirectory name tokens, resolved under plans/ -->
`pre-orianna/implemented`, `pre-orianna/archived`. <!-- orianna: ok -- subdirectory name tokens, resolved under plans/ -->

### Why top-level pre-orianna (not under archived)

- The Orianna-gate-v3 physical guard at
  `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` gates the four phase
  directories `plans/{approved,in-progress,implemented,archived}/` at tool-call <!-- orianna: ok -- brace-expansion glob prose, not a file path -->
  time. Moving 73 proposed plans into `plans/archived/pre-orianna/` would <!-- orianna: ok -- hypothetical alternative directory, not on disk -->
  require Orianna dispatch for every move; a sibling directory avoids that
  ceremony for a pure grandfather-sweep.
- Structural linters (`pre-commit-zz-plan-structure.sh`, <!-- orianna: ok -- bare filename, full path in T2 -->
  `pre-commit-t-plan-structure.sh`) already exempt `plans/archived/` <!-- orianna: ok -- bare filename, full path in T2 --> <!-- orianna: ok -- directory/glob path, not a file --> and, as
  of the current tree, `plans/pre-orianna/`. <!-- orianna: ok -- directory/glob path, not a file --> Since pre-Orianna plans often
  fail rule 1 (canonical Tasks heading) or rule 4 (path citations that no
  longer exist), we need the exemption regardless — and a sibling directory
  is semantically clearer: *grandfathered*, not *archived-by-policy*.

### Why preserve phase subfolders

Some pre-Orianna plans are genuinely informative (implementation history);
keeping the original phase as a subfolder preserves that signal without any
body edits.

### Scope — out

- Editing plan bodies. This is a pure relocation; every `git mv` preserves
  history with zero content change.
- Touching plans that already carry `orianna_gate_version: 2`.
- Deleting anything. Plans stay in the tree; they just move.
- Concern-subdir plans under `work/` or `personal/` subfolders that already <!-- orianna: ok -- relative subdirectory prose, resolved under each phase dir -->
  carry the v2 gate field. Only plans lacking that field match the filter.

## 3. Design

### Identification

A plan is pre-Orianna iff its frontmatter lacks `orianna_gate_version: 2`. The filter:

```sh
find plans -name '*.md' -type f -not -name '_template.md' \
  | while read f; do grep -q 'orianna_gate_version: 2' "$f" || echo "$f"; done
```

Count by source phase at move time: 73 proposed, 0 approved, 9 in-progress, 41
implemented, 8 archived = **131 plans**.

### Move procedure

Per pre-Orianna plan at its current location:

1. `mkdir -p plans/pre-orianna/<phase>/` <!-- orianna: ok -- directory/glob path, not a file -->
2. `git mv` the file to `plans/pre-orianna/<phase>/<basename>.md` <!-- orianna: ok -- directory/glob path, not a file -->

One commit captures all moves. No body edits.

### Interaction with the Orianna-gate-v3 physical guard

The sole lifecycle gate is `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`
(PreToolUse hook wired in `.claude/settings.json`). Its `is_protected_path`
helper (lines 95-108) matches exactly four roots:

```
plans/approved/*|plans/approved
plans/in-progress/*|plans/in-progress
plans/implemented/*|plans/implemented
plans/archived/*|plans/archived
```

`plans/pre-orianna/**` is NOT in that set, so writes and moves into the <!-- orianna: ok -- glob pattern, not a file path -->
destination are unrestricted for any agent. Moves OUT of
`plans/{approved,in-progress,implemented,archived}/` by an mv/cp/rm Bash <!-- orianna: ok -- brace-expansion glob, not a file path -->
call are, however, gated — every pre-Orianna plan currently sitting in one of
those four dirs requires either an Orianna dispatch or Duong's admin identity
(git authors `harukainguyen1411` / `Duongntd`) to relocate.

**Chosen path — executed:** the mass relocation ran under Duong's admin
identity in commit `c79dfd9` ("chore: archive 131 pre-Orianna plans into
plans/pre-orianna/"). The PreToolUse guard's identity chain
(`agent_type` → `CLAUDE_AGENT_NAME` → `STRAWBERRY_AGENT`, fail-closed on
empty) is bypassed for admin git authors at the commit author level per
CLAUDE.md Rule 19. One atomic commit, 131 renames, zero body diffs. No
Orianna dispatch required for future repeats of this *grandfather-sweep*
pattern provided Duong is the committing identity; if a non-admin agent needs
to continue the sweep (e.g. for a future batch lacking the gate field), route
through Orianna via `Agent(subagent_type='orianna')`.

### Legacy-script note

The v1/v2 tooling referenced in earlier drafts of this plan <!-- orianna: ok -- following cites retired script paths, now archived -->
(`scripts/plan-promote.sh`, `scripts/orianna-sign.sh`, <!-- orianna: ok -- retired v1 scripts, now under scripts/_archive/v1-orianna-gate/ -->
`scripts/hooks/pre-commit-plan-promote-guard.sh`) has been archived under <!-- orianna: ok -- retired v2 hook, now under scripts/hooks/_archive/v2-commit-phase-plan-guards/ -->
`scripts/_archive/v1-orianna-gate/` and <!-- orianna: ok -- archive directory path, awk-incompatible -->
`scripts/hooks/_archive/v2-commit-phase-plan-guards/` and plays no role in the <!-- orianna: ok -- archive directory path, awk-incompatible -->
v3 regime. They are listed here only to forestall confusion for readers
chasing older references.

### Structural-lint exemption — already present

Both plan-structure hooks currently include `plans/pre-orianna/*` <!-- orianna: ok -- directory/glob path, not a file --> in their
skip case alongside `plans/_template.md` and `plans/archived/*`: <!-- orianna: ok -- directory/glob path, not a file -->

- `scripts/hooks/pre-commit-zz-plan-structure.sh:48` <!-- orianna: ok -- path + line-number anchor, not a file path -->
- `scripts/hooks/pre-commit-t-plan-structure.sh:35` <!-- orianna: ok -- path + line-number anchor, not a file path -->

No further hook edits are required. T2 below is therefore a verification
task, not a change task.

### Architecture-doc pointer

`architecture/plan-lifecycle.md` gets a one-paragraph note pointing readers to
`plans/pre-orianna/` <!-- orianna: ok -- directory/glob path, not a file --> for grandfathered plans. No other architecture docs
reference the phase directories in a way that needs updating. CLAUDE.md
needs no edit — its File Structure table describes `plans/` <!-- orianna: ok -- directory path, not a file --> with the five
phase subdirs, and adding `pre-orianna/` <!-- orianna: ok -- directory name token --> as a sibling does not invalidate
that description (the list is non-exhaustive).

### Lifecycle & commits

- Plan file itself (this document) goes directly to main per Rule 4 — no PR.
- The directory-move work landed on main via a normal branch-and-merge path.

## 4. Non-goals

- Body edits, frontmatter edits, or lint cleanups on any relocated plan.
- Migrating pre-Orianna plans onto the v2/v3 gate (they stay grandfathered).
- Any changes to the PreToolUse guard's behavior or protected-path set.

## 5. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Structural linter blocks commit on staged renames | `plans/pre-orianna/*` <!-- orianna: ok -- directory/glob path, not a file --> is already in the exempt case of both hooks (verified on current tree). |
| PreToolUse guard blocks the mass mv | Move executed under Duong's admin identity (commit `c79dfd9`); future agent-driven sweeps route through Orianna dispatch. |
| Loss of git history on move | `git mv` preserves rename detection; `git log --follow` continues to work. |
| Concurrent plan authoring during move | Single atomic commit with all moves; window is seconds. |
| Plan body cites its own old path (rare) | Not fixed; bodies are untouched by policy. Readers following a stale in-plan reference hit "file not found" and can search by basename. |

## 6. Tasks

- [x] **T1** — Identify pre-Orianna plans and write the move list. kind: chore. estimate_minutes: 5. Files: none (transient). DoD: list contains 131 entries, each lacking the v2 gate field. (Completed at move time.)
- [x] **T2** — Verify `plans/pre-orianna/*` <!-- orianna: ok -- directory/glob path, not a file --> is in the exempt case of both structural hooks. kind: chore. estimate_minutes: 5. Files: `scripts/hooks/pre-commit-zz-plan-structure.sh`, `scripts/hooks/pre-commit-t-plan-structure.sh`. DoD: grep confirms the pre-orianna glob alongside the archived glob in the `continue` branch of the staged-file loop in both hooks. (Verified: zz hook line 48, t hook line 35.)
- [x] **T3** — Create `plans/pre-orianna/<phase>/` and `git mv` all 131 pre-Orianna plans, preserving the originating phase. <!-- orianna: ok -- templated directory path with <phase> placeholder --> kind: chore. estimate_minutes: 20. Files: 131 renames. DoD: one commit with 131 renames; `git diff --cached --stat` shows zero content changes on moved files. (Landed in commit `c79dfd9` under Duong's admin identity.)
- [ ] **T4** — Add a Grandfathered-plans note to `architecture/plan-lifecycle.md` pointing at `plans/pre-orianna/`. <!-- orianna: ok -- directory/glob path, not a file --> kind: chore. estimate_minutes: 5. Files: `architecture/plan-lifecycle.md`. DoD: the doc's Grandfather-rules section mentions the new directory with a one-line pointer.

Total remaining estimate: 5 minutes.

## Test plan

`tests_required` is false — this is a pure directory relocation with no runtime
behavior change. Sanity checks instead of tests:

- Move-history preservation: `git log --follow` on a sampled pre-orianna plan continues past the rename commit (sample three, one per non-empty source phase).
- No body changes: `git diff --cached --stat` at commit time showed 0 insertions and 0 deletions on every moved plan (pure rename) — verified at commit `c79dfd9`.
- Guard silence on pre-orianna destinations: the PreToolUse guard's `is_protected_path` does not match `plans/pre-orianna/*` <!-- orianna: ok -- directory/glob path, not a file --> (confirmed by reading the helper — four phase roots only).
- Structural-lint exemption: staging a known-bad plan under `plans/pre-orianna/<phase>/` and running the hook returns 0. <!-- orianna: ok -- templated directory path with <phase> placeholder -->

## Architecture impact

No new architecture concepts introduced. `architecture/plan-lifecycle.md`
receives a one-paragraph note (T4) pointing readers to `plans/pre-orianna/` <!-- orianna: ok -- directory/glob path, not a file -->
for grandfathered plans. Documentation-only; no lifecycle rules, guard
behavior, or identity-resolution contracts change.

## Rollback

`git revert` on the move commit restores all 131 plans to their original
phase directories. No state outside git changes, so no other cleanup is
needed. The plan file itself stays — it documents the decision history.

## Open questions

- **OQ1** — Should `plans/pre-orianna/` <!-- orianna: ok -- directory/glob path, not a file --> eventually fold into `plans/archived/` <!-- orianna: ok -- directory/glob path, not a file -->
  when the grandfather population reaches zero (no more migrations pending)?
  Recommendation: defer. Revisit when the last pre-Orianna plan transitions
  to the current gate or is deleted. Until then the sibling directory is the
  lower-friction home — and folding into `archived/` would reintroduce the <!-- orianna: ok -- directory name prose, resolved under plans/ -->
  PreToolUse-guard friction this plan avoids.
