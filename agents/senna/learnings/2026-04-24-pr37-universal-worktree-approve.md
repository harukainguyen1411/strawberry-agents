# PR #37 — Universal Worktree Isolation — APPROVE

**Date:** 2026-04-24
**PR:** harukainguyen1411/strawberry-agents#37
**Verdict:** APPROVE with one suggested fix (non-blocking)

## Scope

Code-quality + security review of universal worktree isolation flip (opt-in → opt-out regime).
Three-commit PR:
- C1 `ff2d3e0` — `scripts/subagent-merge-back.sh` (+247 lines) + Evelynn/Sona CLAUDE.md doc sections
- C2 `ad63e39` — 3 xfail test files (universal, nested-guard, parallel merge-back)
- C3 `e209737` — hook rewrite: bash wrapper adds nested-dispatch guard, Python flips default from frontmatter-opt-in to OPT_OUT={"skarner","orianna"} allowlist

## Independent verification

Cloned PR branch to `/tmp/pr37-check`, checked out each commit, ran test suite:

| Test | C2 state | C3 state |
|------|----------|----------|
| test-agent-default-isolation-universal.sh | 4/11 pass, 7 FAIL (INV-1 ×6 + INV-8) | 11/11 ✓ |
| test-nested-dispatch-guard.sh | 3/4 pass, 1 FAIL (INV-4 assertion) | 4/4 ✓ |
| test-agent-default-isolation.sh (existing) | 6/6 (C2 didn't touch it) | 6/6 ✓ with updated yuumi assertion |
| test-parallel-worktree-merge-back.sh | 6/6 (helper already present at C1) | 6/6 ✓ |

Matches Jayce's capture claims exactly. xfail-first discipline honored.

## Key findings

1. **`subagent-merge-back.sh:56`** — `git push origin main | while read ...` pipeline swallows push failure under `set -e` (pipe exit status is the while-loop's, always 0). Line 60 has `|| warn`, line 112 has `|| true`, line 56 has neither. Silent origin-main-push failure is the bite-weeks-later kind of bug. Suggested fix: append `|| warn "..."` or use `PIPESTATUS[0]` check.

2. **`subagent-merge-back.sh:193`** — `git merge --no-ff ... || true` swallows all failures. Empty `CONFLICTED_FILES` is the clean-merge signal, so a non-conflict merge failure (bad ref, unborn HEAD) reads as success. Not exploitable in current call-sites but defensive pre/post HEAD-compare would harden it.

3. **`subagent-merge-back.sh:214`** — `for f in $CONFLICTED_FILES` word-splits on whitespace; filenames with spaces would mis-bucket. Low-risk on this repo.

4. **`agent-default-isolation.sh:110-127`** — nested-dispatch guard via `git-dir != git-common-dir` is canonical worktree-detection. OPT_OUT set + caller-explicit-isolation-wins + `default_isolation: none` frontmatter opt-out all correct. Error paths fail-open (pass-through) which is right for hooks.

## Security

No shell-injection surface — all inputs are git-resolved refs or fixed path patterns. No secret handling. No plaintext-token exposure.

## Rule compliance

- Rule 10 (POSIX-portable bash): ✓
- Rule 11 (never rebase): ✓ — uses `--ff-only` / `--no-ff` only
- Rule 18 (author≠approver): ✓ — review posted via `--lane senna` as `strawberry-reviewers-2`

## Process note

Preflight `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returned `strawberry-reviewers-2` before posting. Kept hygiene.

## Link

Approved review on PR #37 by `strawberry-reviewers-2`.
