# Learnings — reviewer-auth.sh smoke test (2026-04-19)

- `scripts/reviewer-auth.sh gh api user --jq .login` returns `strawberry-reviewers` — preflight confirmed working.
- `reviewDecision` flips to `APPROVED` when `strawberry-reviewers` approves a PR authored by `Duongntd`. GitHub treats them as distinct identities — Rule 18 is now structurally satisfiable.
- `tools/decrypt.sh` outputs a status line (`decrypt.sh: wrote GH_TOKEN to ...`) to stderr and sends no stdout; command output from the exec'd child goes to stdout normally.
- Draft PRs still receive reviews and the reviewDecision field is populated correctly.
- `gh pr close --delete-branch` closes and removes the remote branch in one call; worktree can then be removed with `git worktree remove`.
- Smoke test took < 5 minutes end-to-end. Good candidate for future regression/verification cadence.
