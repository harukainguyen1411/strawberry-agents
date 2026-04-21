# Plan-structure hook false-positives on `(d)` and `h)` substrings

**Date:** 2026-04-20
**Context:** Karma authored the Orianna work-repo routing plan. Pre-commit structural hook blocked twice:
1. H1 (`#`) section headings instead of required H2 (`##`) for `## Test plan` detection.
2. Alternative time unit literals: `(d)` in a lettered enum `(a)(b)(c)(d)` inside `## Tasks` prose; `h)` inside `(1h)` time annotations.

## Root cause

`scripts/_lib_orianna_estimates.sh` does bare substring match for `h)` / `(d)` / `hours` / `days` / `weeks` inside the `## Tasks` section. No word-boundary check, no context-awareness. Triggers on any text containing those substrings — even prose enumerations and parenthetical notes.

## Lesson for commissioning plans

When commissioning Karma (or any plan author) for a quick-lane plan:

1. **Require self-verification before hand-off.** Brief must include: "Before your final message, run `for f in <target>; do ( . scripts/_lib_plan_structure.sh && check_plan_structure \"$f\" ) done` and paste output. Fix blocks before closing."
2. **Prefer numbered enumerations over lettered.** `(1)(2)(3)(4)` instead of `(a)(b)(c)(d)`. Zero risk.
3. **Never embed `h)` or `(d)` in `## Tasks` prose.** Even in time annotations like `TOKEN_EXPIRY (1h)` — rewrite as `(60 min)` or spell out `one hour`.
4. **All section headings H2 (`##`).** Document title can be H1, but all other sections must be H2 for the hook's regex to find them.

## General pattern

Pre-commit hooks doing substring match (not regex with word boundaries) are brittle. When a hook blocks on what looks like a false positive:
- Check `scripts/_lib_*` for the exact matching logic.
- If substring-based, rewrite to avoid the trigger token. Do NOT argue with the hook.
- File a note for the hook author to tighten the match (future ADR).
