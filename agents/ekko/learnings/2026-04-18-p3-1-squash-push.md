# P3.1 — Squash + Force-Push Orphan Tree to Public Remote

**Date:** 2026-04-18
**Task:** Migration Phase 3.1

## What Worked

- `git reset --soft $(git rev-list --max-parents=0 HEAD)` correctly stages all 6 parametrization commits' changes on top of the orphan root, then `git commit --amend` collapses them into 1 clean commit.
- Viktor's working dir had origin pointing to a local bare clone — needed `git remote set-url origin <github-url>` rather than `git remote add origin`. Worth checking `git remote -v` before any push.
- The pre-commit hook in `/tmp/strawberry-app-migration` runs gitleaks and passed cleanly (0 findings) on the amend.

## File Count Note

Recursive tree object count (795) includes directory tree objects, not just blobs. Not directly comparable to flat file counts (602 from Phase 1). For a pure file count, filter `.tree | map(select(.type == "blob")) | length`.

## Auth Pattern

`gh auth status` should always be the first check for any cross-account GitHub push. The active account showed clearly with `Active account: true`.
