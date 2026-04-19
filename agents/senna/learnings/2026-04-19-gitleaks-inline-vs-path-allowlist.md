# Gitleaks inline vs path-level allowlist — drift detection pattern

**Date**: 2026-04-19
**PR**: harukainguyen1411/strawberry-app#19

## Finding

A "verbatim restoration" commit can still drift if the author adds inline
`# gitleaks:allow` suppressions that were not in the original. These are
invisible to a line-count check (adds +1 per line) and easy to miss in a diff.

## Verification method

Use blob SHA comparison, not line count:
1. `git hash-object --stdin < <(git show <base-sha>:<path>)` in the source repo
2. `gh api repos/<owner>/<repo>/git/trees/<branch-sha>?recursive=1 | jq ...` for target
3. Compare the two 40-char blob SHAs — any mismatch = content diverged

## Design choice

`# gitleaks:allow` inline comments are only effective when the pre-commit
hook runs the *local* gitleaks config (i.e. `gitleaks detect --config .gitleaks.toml`).
If the hook uses `~/.config/git/gitleaks.toml` (global), inline comments
have no effect — only the global allowlist matters.

When both a path-level allowlist entry AND inline comments are added,
they are redundant at the repo level and the inline approach creates
content drift from the base.
