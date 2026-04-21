# Learning: Orianna re-sign after plan body edited post-promotion

**Date:** 2026-04-21
**Task:** Re-sign MAD + BD at `approved` phase after Yuumi inlined Tasks sections (commits 26bfe59 MAD, 1fbbec8 BD).

## The Problem

`orianna-sign.sh <plan> approved` requires the plan to be in `plans/proposed/`. After promotion to `plans/approved/`, the script refuses with "phase 'approved' requires plan to be in plans/proposed/". If the body changes after promotion (e.g. Tasks inlined), the `approved` signature becomes stale. The `plan-promote.sh` carry-forward check then blocks the next promotion.

## Recovery Procedure

1. Remove the stale `orianna_signature_approved` field from frontmatter (Edit + commit).
2. Move the plan back to `plans/proposed/work/` using `git mv`.
3. Change `status:` from `approved` to `proposed` in frontmatter.
4. Commit the move + status change (`chore: move <slug> back to proposed for re-sign recovery`).
5. Apply any block-finding fixes in a separate commit before signing (`chore: orianna fixes for <slug> approved re-sign`). Never leave fixes mixed with the signature commit.
6. Run `bash scripts/orianna-sign.sh plans/proposed/work/<plan>.md approved` — this runs the plan-check gate and signs.
7. Run `bash scripts/plan-promote.sh plans/proposed/work/<plan>.md approved` — moves back to `approved/work/`, verifies signature, pushes.
8. Run `bash scripts/orianna-sign.sh plans/approved/work/<plan>.md in_progress` — runs task-gate-check + carry-forward of approved sig, signs.
9. Run `bash scripts/plan-promote.sh plans/approved/work/<plan>.md in-progress` — moves to `in-progress/work/`, verifies both sigs, pushes.

## Pitfalls Encountered

### 1. Staging bleed from other agents
Other agents occasionally stage files into the working tree. Always check `git diff --cached --name-only` before committing. Unstage unrelated files with `git restore --staged <file>` before each commit.

### 2. The empty fixes commit
`git add <file> && git commit` sequence can silently produce empty commits if `git restore --staged` was run on the file between add and commit. Always verify `git diff --cached --name-only` shows the intended file before committing.

### 3. orianna-signature-guard pre-commit hook
The hook (`pre-commit-orianna-signature-guard.sh`) requires a signing commit to touch ONLY the signature line. If the signing commit's diff (against HEAD) includes other line changes, it blocks. Solution: always commit suppressor/body fixes in a separate commit BEFORE running `orianna-sign.sh`.

### 4. mktemp failure in pre-commit-zz-plan-structure.sh
`mktemp: mkstemp failed on /tmp/pre-commit-zz-plan-structure-XXXXXX.tmp: File exists` — macOS bug when the temp dir has leftover files. If it blocks the promotion commit (which `plan-promote.sh` runs), recover by committing manually after the git mv already staged by the script.

### 5. Stale plan-path self-reference
BD plan had a self-reference: `plans/approved/work/2026-04-20-s1-s2-service-boundary.md §3.2` inside a task acceptance line. While the plan is temporarily in `proposed/work/`, Orianna flags this as a non-existent path. Fix: add `<!-- orianna: ok — future plan location; currently in proposed/work/ during re-sign -->` suppressor. This suppressor should be retained (it's accurate even post-promotion since the reference is a documentation anchor).

## Suppressor Count Added (BD)

2 suppressors added:
1. Line 528: self-reference to `plans/approved/work/...§3.2` (future-path suppressor)
2. Line 679: `git rm tools/demo-studio-v3/sample-config.json` (cross-repo path suppressor)

## Inlined Tasks Drift Observed

No drift in content — Yuumi's inlining was verbatim copy from the sibling `-tasks.md` files. The only semantic change was adding `_Source: company-os/plans/...` headers above each Tasks section to record provenance. These headers do not affect correctness.

## Final SHAs

| ADR | approved sig commit | in_progress sig commit | promotion commit |
|-----|---------------------|------------------------|------------------|
| MAD | b6e239b | 23b9673 | 465c01a |
| BD | eea4a43 | 2ae4b37 | 2d0fbe0 |
