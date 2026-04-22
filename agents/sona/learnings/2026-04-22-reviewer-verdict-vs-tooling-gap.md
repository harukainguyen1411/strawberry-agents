# Reviewer verdict is independent of reviewer-auth tooling success

**Date:** 2026-04-22
**Context:** PR #69 Firebase auth Loop 2b — Lucian dispatched, `reviewer-auth.sh` denied for `missmp/company-os`, verdict written to `/tmp/lucian-pr-69-verdict.md`.

## Lesson

When a reviewer agent cannot submit a formal GitHub review (due to `reviewer-auth.sh` access denial or sandbox restriction), the verdict they produce is still substantive and must be honored as a quality gate. Do not treat "reviewer-auth failed" as equivalent to "reviewer passed" or "review did not happen."

In the PR #69 case: Lucian's request-changes finding (test strategy divergence — plan promised Playwright + emulator, impl shipped source-grep pytest) is a real, substantive objection. The fact that Lucian could not push it as a GitHub review via `strawberry-reviewers-2` (which lacks access to `missmp/company-os`) does not reduce it to a suggestion. The plan fidelity gate stands.

## Practical rule

When relaying review outcomes to Duong:
- State the verdict clearly (LGTM / conditional LGTM / request-changes / advisory).
- Note whether the review was posted as a formal GitHub review or as a file verdict (Yuumi-fallback).
- Do not use the fallback path as an implicit downgrade of the verdict weight.
- If the verdict is request-changes, treat it as a merge blocker regardless of how it arrived.

## Corollary

This pattern will recur on every `missmp/company-os` PR until `strawberry-reviewers` gets collaborator access. Build the habit of reading the verdict file directly (or asking for it) rather than inferring from the reviewer-auth outcome.
