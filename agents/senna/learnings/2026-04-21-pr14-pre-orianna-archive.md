# PR #14 — Pre-Orianna plan archive review

**Date:** 2026-04-21
**PR:** [#14](https://github.com/harukainguyen1411/strawberry-agents/pull/14) — chore: archive 131 pre-Orianna plans into plans/pre-orianna/
**Author:** duongntd99 (Karma quick-lane execution)
**Verdict:** APPROVED

## Shape of the PR

- 134 changed files, but totals of +10/-2 lines. 130 files were pure renames (`similarity index 100%`).
- Real edits only in: `architecture/plan-lifecycle.md` (+8), `scripts/hooks/pre-commit-t-plan-structure.sh` (+1/-1), `scripts/hooks/pre-commit-zz-plan-structure.sh` (+1/-1).
- GitHub's `pr view --json files` API caps at 100 files; always verify against `additions`/`deletions` totals when large rename sets are in play.

## Verification techniques used

1. **Rename integrity** — `git log --follow` on a sample renamed file walks through pre-rename commits. Good quick sanity check.
2. **Byte-identity** — pipe `git show <branch>:<path>` through `md5` on both the pre-rename and post-rename path; matching hashes prove no content drift slipped in.
3. **Additions/deletions sanity** — if the PR claims "pure renames," the repo-level additions count should equal the sum of only the expected-edit files.
4. **Glob exempt audit** — when a hook's allowlist gets extended (`plans/_template.md|plans/archived/*|plans/pre-orianna/*`), check that the new glob doesn't over-match. Shell case globs don't match `/` across segments when anchored at a phase boundary, so `plans/pre-orianna/*` ONLY matches children of `plans/pre-orianna/`, never `plans/proposed/*`.

## Things to scan for in archive-move PRs

- Runtime scripts that iterate `plans/**` and might silently include or exclude the new subtree.
- Hook gate patterns (`case`/`grep`/awk) that assume the five-phase top-level layout.
- Cross-reference scripts (`plan-promote.sh`, `orianna-sign.sh`, `orianna-verify-signature.sh`) whose EXPECTED_DIR / allowlist are source-of-truth for what "valid plan location" means.
- Stale path refs in comments/error messages — note but don't block (pre-existing drift).

## Lessons

- **Load-bearing evidence before approving a big rename:** md5 match + `git log --follow` + additions total. Three independent signals, cheap to collect.
- **Hook glob patterns are shell `case` semantics, not regex.** `plans/pre-orianna/*` matches anything under `plans/pre-orianna/` but NOT anything under sibling dirs — reviewers should mentally test against each existing phase dir to confirm no over-match.
- **Pre-existing stale references (e.g. plan-promote.sh citing a plan that has since moved from in-progress to implemented) are out-of-scope for an archive PR** — flag as suggestion, not block. The PR isn't changing those files.
