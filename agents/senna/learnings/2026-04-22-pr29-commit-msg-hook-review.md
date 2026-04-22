# 2026-04-22 — PR #29 commit-msg AI-coauthor hook review

## Context

Reviewed `feat/commit-msg-no-ai-coauthor-hook` (70 LoC hook + 134 LoC test + dispatcher wiring + docs). Implements `plans/in-progress/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md`. Motivation: Syndra's 663c274 landed with a Claude co-author trailer requiring a 3-commit revert chain.

## Verdict

Approved. Implementation matches approved plan §3/§4 exactly; all 8 tests pass; ~20 edge-case probes hold up.

## Review techniques that worked

1. **Shallow-clone the PR branch to /tmp** for local probing — faster than repeated `gh api` calls and lets me run the test suite myself. `git clone --depth 1 --branch <head>` was fine.
2. **Run the test suite end-to-end first** before writing any comments. If 8/8 pass on my box, that's real; if not, I know where the authored claims diverge.
3. **Generate an edge-probe matrix from first principles**, not from the PR's own test fixtures. The PR tests prove what the author thought mattered; edge probes prove what the author forgot. Key axes I hit: case variants, anchor escapes (leading whitespace, mixed case trailer name), substring vs word-boundary, domain vs localpart, free-text vs trailer-anchored, CRLF, empty file, bare-email-no-brackets, alphanumeric-suffix.
4. **Separate "implementation diverges from plan" from "implementation and plan both fail to cover X"**. The former is a code bug; the latter is a scoping question for Lucian. In this PR, §5 explicitly scoped out free-text AI-attribution scanning, so the `Generated with Claude Code` non-catch is correct behavior, not a bug.
5. **Detect PR-body drift from implementation.** The PR summary claimed the hook catches `Generated with Claude Code` banners, but the hook only anchors on `^Co-Authored-By:`. That's a PR-body accuracy nit worth flagging without blocking merge.

## Edge cases that would have looked like real bugs but weren't

- Leading whitespace before `Co-Authored-By:` evades `^` anchor. Theoretical but not a real threat — real Claude Code output is flush-left, and git canonicalizes trailers during `interpret-trailers`.
- `Claude3` evades PATTERN_A's right-hand `[[:space:])>]` character class because `3` isn't whitespace or a bracket. Real Claude trailers always have a space after the vendor name (e.g., "Claude Opus 4.7"), so the pattern is tight enough for observed threats.
- Both gaps would require additional regex machinery or switching to PCRE. For a commit-msg hook with a stated threat model of "prevent Syndra 663c274 recurrence," the chosen tightness is correct.

## Rule 10 / POSIX portability

Both scripts use `#!/usr/bin/env bash` and stay within bash 3.2+ features. Using bashisms (`local`, `$(())`, arrays) is fine when the shebang requests bash explicitly; Rule 10 means "runnable on macOS and Git Bash" — both ship bash. The rule is not "must run under `/bin/sh`". I verified: no `[[ ]]`, no process substitution, no `{1..N}` brace expansion with variables, no associative arrays. Clean.

## Dispatcher subtlety

The `install-hooks.sh` dispatcher loops `ls "$HOOKS_SRC"/*.sh` (non-recursive) and matches against `VERB-*.sh` glob after substitution. This means:
- Test files in `scripts/hooks/tests/` are NOT picked up (good — tests shouldn't run as hooks).
- The existing `"$@"` propagation correctly passes git's `$1` (commit-msg path) to the sub-hook.

Worth remembering for future hook additions: if a hook needs to run from a subdir, refactor the dispatcher first.

## Identity verification

`scripts/reviewer-auth.sh --lane senna gh api user --jq .login` → `strawberry-reviewers-2`. Good. Used `--lane senna` on every call per startup protocol. PR-author identity was `duongntd99` (not `strawberry-reviewers-2`), so Rule 18 self-approval collision doesn't apply.

## Review URL

https://github.com/harukainguyen1411/strawberry-agents/pull/29#pullrequestreview-4155654142
