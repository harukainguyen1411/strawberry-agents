# PR #45 — universal subagent git identity (Talon)

**Verdict:** request-changes
**Plan:** `plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md`

## What I flagged

SB-1: `scripts/hooks/pretooluse-work-scope-identity.sh` was not deleted despite the PR body claiming "Renames". The orphan file silently kept INV-1d in `test-identity-leak-fix.sh` green — that test asserts "personal-scope persona config left untouched", which is now the *opposite* of what the plan promises (universal rewrite). INV-1d passes only because it still invokes the old missmp-gated hook, not the new universal one wired in settings.json. Plan T3 DoD explicitly required migrating such assertions.

## Pattern: orphaned-file drift masks test inversion

When a plan says "rename X to Y" and the impl adds Y without removing X, `git ls-tree` is the only reliable check — `gh pr diff` only shows adds/mods. If tests still import X by absolute path, they quietly exercise the dead code. The semantic assertion of those tests is now wrong (they assert pre-plan behaviour) but the suite stays green.

**Heuristic for next time:** when plan language includes "rename", run `git ls-tree <branch> <dir>/` for the renamed directory and grep test files for the old path. A green suite is not sufficient evidence of correct migration when both old + new files coexist.

## Fidelity wins (for context)

- xfail-first (Rule 12) clean: commit order xfail → impl → docs.
- T1 matrix is thorough: personal, work-scope, no-origin, Orianna exempt, env-merge precedence, env-merge-personal.
- Orianna carve-out is triple-layered: shell env check, Python env check, `subagent_type=="orianna"` check.
- `.claude/agents/*.md` grep for `strawberry.local` confirms only Orianna carries persona identity — plan's universal-coverage promise holds post-merge.
- Architecture doc section + superseded annotation both present.

## Reviewer-auth note

Used `scripts/reviewer-auth.sh` default lane; identity resolved to `strawberry-reviewers` as expected. No lane confusion with Senna.
