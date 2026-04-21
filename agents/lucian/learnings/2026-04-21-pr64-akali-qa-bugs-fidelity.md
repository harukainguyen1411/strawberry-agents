# PR #64 — Akali QA bugs 2/3/4 fidelity review

Date: 2026-04-21
Repo: `missmp/company-os` PR #64 (fix/akali-qa-bugs-2-3-4)

## Verdict

APPROVE on fidelity grounds. Bug-fix PR, no ADR. Rules 12/13 satisfied cleanly:
- 49cd838c xfail precedes c242c8e2 impl on same branch
- 3 regression tests, one per bug, all flipped green in fix commit
- QA report linked in PR body and in test docstrings

## Drift notes

- PR targets `main` but branch descends from `feat/demo-studio-v3`; `mergeable: CONFLICTING`. Commit-scoped diff is tight (3 files), but PR-level file list reports 500+ files from the ancestor. Needs retarget or rebase-via-merge before the non-author approval required by Rule 18.
- Bug 3 test asserts string presence (`window.location.hostname`, `run.app`) in dashboard.html rather than DOM behavior. Fine as a static regression, brittle against future rewrites.

## Access gap recurrence

Again hit the `strawberry-reviewers` → `missmp/company-os` 404. Confirmed still unresolved — same as PR #57, #59, #61. Review body delivered to Sona for manual post; cannot submit via reviewer-auth until bot is added as collaborator.

## Commit prefix scope note

Rule 5 wording in strawberry-agents CLAUDE.md pins `fix:` to `apps/**`; this PR touches `tools/`. In the **work repo** (`missmp/company-os`), `fix:` is conventional and accepted — the apps/** scoping rule is a strawberry-agents artifact and does not apply cross-repo. Not a fidelity issue.
