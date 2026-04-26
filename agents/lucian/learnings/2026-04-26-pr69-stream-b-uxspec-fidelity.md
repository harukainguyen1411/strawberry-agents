# PR #69 Stream B (UX Spec plan-template + linter) — fidelity

PR: https://github.com/harukainguyen1411/strawberry-agents/pull/69
Plan: `plans/approved/personal/2026-04-25-frontend-uiux-in-process.md` Stream B (T-B1..T-B4)
Verdict: APPROVE with two drift notes.

## Pattern

Stream-of-multi-stream plan PRs decompose to per-stream task ranges (here T-B1..T-B4 of an A..E plan). Fidelity check collapses to:
1. Rule 12 chain — xfail commit parents impl commit (single `gh api commits/<sha>` per commit for parent SHA + file scope).
2. Per-task DoD verbatim grep against the impl diff (six required subsections, D1 path-glob comment, UX-Waiver bypass).
3. Fixture-case coverage table from xfail test source vs DoD-declared cases (a-d).
4. Cross-stream scope leak grep — confirm no files outside the stream's declared `Files:` block.

## Drift notes worth surfacing

- **T-B4 follow-up not surfaced in PR body.** DoD explicitly notes "integrated into Orianna's promote-time gate ... note as follow-up if non-trivial" but PR didn't carry this forward. Pattern: when plan DoD has parenthetical "note as follow-up if X", check PR body for that follow-up explicitly. Easy miss.
- **Shared-glob single-source-of-truth foreshadowing.** Stream C T-C3 declares `scripts/lib/uxspec-globs.sh` as the single source. Stream B linter inlines its own regex (correct for now, but the migration is the Stream C reviewer's gate to enforce).

## Rule 12 chain shape (textbook)

- xfail commit's test exits 0 with explicit `XFAIL` sentinel lines listing each future check (`TB1_UXSPEC_HEADER_PRESENT` etc.) — clean readable artifact, easy to verify by patch-grep alone.
- impl commit's parent SHA == xfail commit's SHA (single API call per commit verifies chain).
