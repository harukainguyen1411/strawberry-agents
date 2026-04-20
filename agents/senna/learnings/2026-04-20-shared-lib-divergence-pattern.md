# Learning — Shared-lib / hook divergence is a BLOCK-worthy correctness pattern

**Date:** 2026-04-20
**Context:** PR #6 (plan-structure-prelint) — Talon factored structural checks into `scripts/_lib_plan_structure.sh` (T1) and then reimplemented them inline in `scripts/hooks/pre-commit-plan-structure.sh` (T3) as a single-awk-pass for performance. The two implementations drifted.

## The pattern

When a PR's architecture says "shared library X, and hook Y uses the same logic for speed," the reviewer job is to **read both and diff them semantically**, not just check that both exist. Two implementations of the same check is duplication, and duplication drifts.

Concretely: lib.sh extracted the value and required `length > 0`; hook.sh only checked that the key's regex matched (`^concern:[[:space:]]`). A frontmatter line `concern: ` (key + space + empty value) passed the hook and failed the lib. A user would commit, the hook would greenlight, then Orianna's promote-time gate would reject — the exact late-feedback failure the shift-left was meant to eliminate.

## Heuristic for next time

When reviewing PRs that claim "same logic in N places":
1. Diff the regex/extract/validate code paths literally. Different code = different semantics until proven otherwise.
2. Construct edge-case inputs that exercise the **looser** impl's gap: empty values, whitespace-only, unicode, CRLF.
3. If the PR's value prop is "catch X locally before gate Y catches X," then **any divergence where hook is looser than gate defeats the plan**. That's block-worthy, not minor.

## Secondary pattern — word-splitting bashisms flagged by SC2046

`awk '...' $(cat file-list)` is the classic SC2046 hazard. In a script parsing user-controlled file paths, it's a silent-failure vector (paths with spaces → `awk: can't open file ...truncated`). When the paths come from `git diff --cached --name-only`, convention typically forbids spaces, but "convention" is not enforcement; the hook should either reject space-paths with a clear BLOCK or handle them via `xargs -0` / a while-read loop that invokes awk once per file.

## Posting check

Senna lane verification step before posting is non-negotiable — `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` must return `strawberry-reviewers-2`. Verified before posting. Review landed with state `CHANGES_REQUESTED` and `authorAssociation: COLLABORATOR`, distinct identity from Lucian's lane.
