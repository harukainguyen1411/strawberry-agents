# Re-signing an Orianna-gated plan after post-approval body edits

**Date:** 2026-04-22
**Context:** Talon added `architecture_impact: none` frontmatter and `## Architecture impact` section to `plans/in-progress/personal/2026-04-22-explicit-model-on-agent-defs.md` after it had already been signed and promoted. The existing signatures referenced the old body hash and were stale.

## The problem

`orianna-sign.sh` enforces that the plan is in the directory matching the phase:
- `approved` → plan must be in `plans/proposed/`
- `in_progress` → plan must be in `plans/approved/`

A plan already in `plans/in-progress/` cannot be directly re-signed for either phase.

## The solution

Re-walk the promotion chain manually:

1. Strip the stale `orianna_signature_approved` and `orianna_signature_in_progress` fields from the frontmatter.
2. Change `status: in-progress` → `status: proposed`.
3. Copy file to `plans/proposed/personal/`, `git rm -f` from in-progress, `git add` at proposed. Commit (git detects rename ~R098).
4. Run `git restore --staged .` to clear any stray staged files.
5. Run `scripts/orianna-sign.sh plans/proposed/personal/<plan>.md approved` — LLM check runs, signs, commits as Orianna.
6. Change `status: proposed` → `status: approved`. Copy to `plans/approved/personal/`, `git rm -f` from proposed, `git add`. Commit.
7. Run `git restore --staged .` again.
8. Run `scripts/orianna-sign.sh plans/approved/personal/<plan>.md in_progress` — carries forward approved sig verification, LLM check, signs, commits.
9. Change `status: approved` → `status: in-progress`. Copy to `plans/in-progress/personal/`, `git rm -f` from approved, `git add`. Commit.
10. Verify: `scripts/orianna-verify-signature.sh <plan-in-progress-path> approved` and `in_progress` — both should say OK.

## Key notes

- `git rm -f` is needed because the file has local modifications at each step.
- `git restore --staged .` before each sign call is critical — prevents staging contamination.
- The verify script uses `git log --follow` with rename detection; it correctly finds the signing commits through the rename chain.
- The promote-guard hook fires only for moves OUT of `plans/proposed/` — it will check for a fact-check report. Existing reports from the original approval flow satisfy this.
- Each move commit is detected by git as a rename (~R099) because the content is nearly identical.
