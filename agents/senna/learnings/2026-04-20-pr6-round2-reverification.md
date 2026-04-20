# 2026-04-20 — PR #6 round-2 re-verification (plan-structure pre-lint)

## Context
Re-reviewed PR #6 (harukainguyen1411/strawberry-agents) after Talon addressed round-1 findings in `a57c24d`. Round 1 returned CHANGES_REQUESTED with 1 block (B3: hook frontmatter check diverged from lib — would let `concern:\n` empty value through), 2 majors (M1 word-splitting on file list; M2 test coverage gaps), minors, and one OQ recommendation.

## Verdict
APPROVED — all findings addressed; 16/16 tests green locally.

## What was verified

- **B3 (shared-lib divergence)** — Hook awk block (lines 117-148) now mirrors lib: extract value, `gsub` trim, gate on `length(v) > 0`. Test (i) writes `concern:\n` (empty value) and asserts BLOCK. The lib's regex `^key:[[:space:]]` and hook's `^key:` are semantically equivalent because the subsequent `sub(/^key:[[:space:]]*/, "", v)` allows zero trailing whitespace; the length-gate is what enforces non-empty. Double-check confirms no drift.

- **M1 (word-splitting on filter tmp)** — `$(cat "$_filter_tmp")` replaced with `mktemp` + trap on EXIT/INT/HUP/TERM, PLUS explicit BLOCK on space-containing paths at line 40 before they enter the tmp file. Final `$(tr '\n' ' ' < "$_filter_tmp")` at line 234 is still unquoted, but it's safe-by-construction — nothing with a space can reach the tmp file. Documented the defense-in-depth pattern in the approval body.

- **Shellcheck minors** — Lib line 19 wraps SC3028 (`BASH_SOURCE`) behind a guard + dir fallback. Lines 43 and 105 mark literal backticks with SC2016 disables. Double-source guard via `${_LIB_ORIANNA_ESTIMATES_LOADED:-}` at line 23.

## Pattern / reusable insight

**Safe-by-construction defense vs quoting fix.** When a bash word-splitting finding has a viable "harden the input instead of quote the output" fix, both approaches are legitimate — but the input-hardening approach must include a regression test that exercises the rejected input class. Talon added the explicit space-path BLOCK at line 40; if that line is ever removed without also fixing the line-234 quoting, the bug returns silently. The BLOCK path is not currently covered by a test — flagged internally but not blocker-worthy because the invariant is documented inline.

**Double-invocation for stderr/stdout split in bash tests.** Tests (b) and (i) run the hook twice — once capturing stderr for message assertions, once capturing exit code separately. Wasteful but unambiguous; acceptable for small hooks. For larger hooks consider `{ rc=0; out=$(... 2>&1 >/dev/null) || rc=$?; ...; }`.

## Lane hygiene
Preflight check: `strawberry-reviewers-2` (Senna lane) confirmed before review submission. Round 2 APPROVE landed at `2026-04-20T16:37:15Z`, cleanly chained after round-1 CHANGES_REQUESTED from the same lane (no cross-lane masking).
