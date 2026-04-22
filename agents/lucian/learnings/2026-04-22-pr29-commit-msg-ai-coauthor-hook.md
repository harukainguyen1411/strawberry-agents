# PR #29 — commit-msg AI-coauthor hook fidelity

**Date:** 2026-04-22
**Repo:** harukainguyen1411/strawberry-agents
**Plan:** plans/in-progress/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md
**Verdict:** APPROVE

## Key findings

- All 5 plan tasks landed cleanly. Test (7 cases, superset of spec) preceded impl per Rule 12.
- Hook uses POSIX bracket char-classes `[[:space:](]` instead of plan's `\b` — functionally equivalent, all 7 test cases pass, arguably more portable for BSD grep on macOS. Flagged as drift-note not block.
- Scope noise: PR carried 2 unrelated files (swain memory +1 line, P1 plan signature frontmatter) from commits that rode along on the branch. PR body did not acknowledge. Flagged drift-note.

## Patterns worth remembering

- When reviewing hook PRs that follow an existing dispatcher pattern, check:
  1. new verb added AFTER existing verbs (ordering convention)
  2. VERB-substitution loop untouched (if plan said so)
  3. header comment's top-line `verb list` updated to mention new verb
  4. new `<Verb> hooks picked up automatically` section mirrors siblings
- xfail-first commits often have xfail-guard `[ ! -x HOOK ]` → `exit 0`. Verify the guard actually checks for what the impl will create.
- Scope-noise from branch ride-alongs is a recurring theme on agent PRs — mention it as drift-note, don't block unless secret/high-risk.
