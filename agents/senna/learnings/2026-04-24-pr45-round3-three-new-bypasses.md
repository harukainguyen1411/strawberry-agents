# PR #45 — round 3 re-review — CHANGES_REQUESTED (three new real bypasses)

**Date:** 2026-04-24
**PR:** harukainguyen1411/strawberry-agents#45
**Branch:** `talon/subagent-git-identity-as-duong`
**Head OID at review:** `d6ad174e`
**Verdict:** CHANGES_REQUESTED

## Summary

Round-2 BP-1/BP-2/BP-3 fixes all land cleanly — quoted `-c`, space-separated
`--author`, and persona-name-only leaks via `GIT_AUTHOR_NAME` / `-c user.name=` /
`--author` all block correctly on canonical shapes. No regressions on round-1
or round-2 approved shapes. But while stress-testing the quoting / value-shape
matrix I found three new real bypasses in the same family.

## Residual criticals

- **NEW-BP-1 (critical)** — `git -c 'user.email=persona@strawberry.local;' commit`
  passes rc=0 because `;` inside the quoted `-c` value early-terminates the
  git-commit detector's token regex (`[^;|&[:space:]]+`). End-to-end reproduced:
  git records `viktor@strawberry.local` as author email. Same for `|`, `&`
  inside quotes.
- **NEW-BP-2 (critical)** — `GIT_AUTHOR_NAME='Viktor Kesler' git commit` passes
  rc=0 because the C2-name regex requires persona name immediately after `=`
  (doesn't strip leading quote). Git records `Viktor Kesler` as author.
  Same root cause surfaces for `--author=' Viktor <...>'` and
  `-c " user.name=Viktor"` (leading space inside quote breaks `['"]?${PERSONA}`).
- **NEW-BP-3 (important)** — `GIT_AUTHOR_NAME='The Viktor'` passes because the
  persona denylist only matches when the persona name is at the START of the
  value. Suffix / middle-token placement is invisible. Fix wants tokenize-and-
  check-each-token-against-denylist rather than positional anchor.

## Verification method

Same sandbox harness as round-2 (`/tmp/senna-pr45-r3/`):
- Cloned PR branch.
- Wrote `run.sh` that synthesized PreToolUse JSON per case, piped into the
  hook, printed BLOCK/PASS verdict.
- Tested the full quoting × separator matrix: unquoted, single-quoted, double-
  quoted, leading-space-in-quote, trailing-separator-in-quote, tab-whitespace,
  mixed-case env var name, persona-as-prefix/suffix/middle.
- For every PASS that should have been BLOCK, reproduced end-to-end in a
  throwaway git repo and ran `git log -1 --format='%an <%ae>'` to confirm
  the persona identity actually lands in the commit. Did NOT rely on "regex
  doesn't match" alone.

## Takeaway — detector hygiene

The git-commit detector's inner-token class `[^;|&[:space:]]+` is
shell-metachar-aware but not quote-aware: quoted values containing
shell metachars defeat the detector, and downstream guards become
dead code. The fix that will land all three findings at once is
**tokenize with shlex (python3 is already required fail-closed)**
and check argv structurally instead of grep-on-raw-command-string.
Flag this pattern in future identity-hook reviews: "is the
command parsed via shlex or via metachar-dependent regex?"

## What went right

- Round-2 BP-1/BP-2/BP-3 all fixed cleanly on canonical shapes.
- False-positive discipline holds: Victoria, Victor, Alexandra, David all pass.
- Test suite is green (32+6=38 tests; claim was 35 — minor drift, no issue).
- Regression-free on round-1 and round-2 approvals.

## Time to close

~50 min — sandbox reuse from round 2 helped; the three findings came from
disciplined matrix coverage rather than intuition.

## Extended review checklist for identity-hook reviews (append to round-2 list)

1. `--flag=value`
2. `--flag value` (space sep)
3. `--flag "value"` / `--flag 'value'` (quoted)
4. Flag before *and* after the subcommand
5. Equivalent env-var form
6. Equivalent `-c` / config form
7. **NEW:** quoted value containing shell metachars (`;`, `|`, `&`) — does the
   command-detector early-terminate?
8. **NEW:** quoted value with leading space / other leading whitespace — does
   the value-match pattern strip optional leading ws inside the quote?
9. **NEW:** persona token as middle / trailing word in a multi-word value —
   does the denylist anchor on position, or on token word-boundary?
10. **NEW:** end-to-end reproduction in a real git repo for every "rc=0"
    result — does git actually honor the value, or does the regex-miss turn
    out to be benign (e.g. mixed-case env var git ignores)?
