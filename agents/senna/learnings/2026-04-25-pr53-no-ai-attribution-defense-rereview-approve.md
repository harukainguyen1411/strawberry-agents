# PR #53 re-review — no-AI-attribution defense in depth → APPROVE

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/53
**Revision:** c9a5cbcf
**Verdict:** APPROVED (state-flip from prior COMMENTED)

## Context

Prior round I posted COMMENTED with advisory LGTM and 7 findings (F1, F2, S1–S5). Talon shipped fixes for F1, F2, S2, S4; S1/S3/S5 parked per dispatch. State-flip required because prior COMMENTED does not satisfy Rule 18 dual-approval.

## What was actually fixed

- **F1 (prefix anchor too narrow):** Both `scripts/hooks/commit-msg-no-ai-coauthor.sh:81` and `scripts/ci/pr-lint-no-ai-attribution.sh:43` widened from `(^|[[:space:]])` to `(^|[[:punct:][:space:]])`. Catches `(Sonnet)`, `[Opus]`, `"Opus"`, `'Haiku'`, `` `Claude` ``, `:Sonnet:`, etc.
- **F2 (digit boundary missing):** Postfix widened from `([[:space:]]|[[:punct:]]|$)` to `([[:space:]]|[[:punct:]]|[0-9]|$)`. Catches `Sonnet4.6`, `Opus4`, `Claude4`.
- **S2:** "Post-approval clarifications" block added to plan documenting that `.claude/_script-only-agents/` was a planning-time assumption — Orianna lives at `.claude/agents/orianna.md`.
- **S4:** Invariant comment added to `scripts/sync-shared-rules.sh` header warning that prose between adjacent include markers is silently discarded on sync.

Tests: T3 17/17 with 7 new adversarial cases; T5 10/10 with 5 new adversarial cases. Adversarial sweep confirmed.

## Self-correction lesson — `grep` aliasing in Claude Code shell

While verifying F1, an initial probe with `grep` returned that backtick was NOT in `[[:punct:]]`, which would have invalidated the F1 fix for backtick-wrapped markers. I almost flagged this as a critical regression.

Root cause: in Claude Code's zsh shell snapshot, `grep` is aliased to a shell function that ultimately invokes `ugrep` (a third-party PCRE-capable grep), not the system BSD grep. `ugrep`'s `[[:punct:]]` classification differs from POSIX BSD grep.

**Lesson:** When verifying regex behavior in shell scripts, always test against the binary the script actually invokes (`/usr/bin/grep`, `/bin/sh`, etc.), not whatever the interactive shell aliases to. Rule of thumb: in the bash tool environment, prefer absolute paths for grep/sed/awk when verifying production regex semantics. This near-miss could have caused a wrongful re-block.

Verification path that worked:

```sh
type grep                    # exposes aliasing
which -a grep | head -5      # shows path resolution order
/usr/bin/grep --version      # confirms BSD grep 2.6.0-FreeBSD
printf '`\n' | /usr/bin/grep -E '[[:punct:]]'   # actual semantics
```

## Operational

- Identity: `strawberry-reviewers-2` (Senna lane via `scripts/reviewer-auth.sh --lane senna`).
- Both approvals now in place; reviewDecision `APPROVED`. PR is mergeable by a non-author per Rule 18.
- No new blockers. S1/S3/S5 deferred per dispatch as agreed.
