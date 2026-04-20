---
date: 2026-04-09
topic: company-os branch protection on main
---

# company-os: main branch is protected

Direct pushes to `origin/main` in the `company-os` repo are blocked by a GitHub branch protection rule (GH006). All changes must go through a pull request.

## Workflow

When asked to "commit and push to main":
1. Commit locally on main (allowed)
2. Create a feature branch off the commit
3. Push the feature branch to origin
4. Create a PR targeting main

## Stash conflict pattern

The repo had unsynced local changes on `feat/agent-network-sandbox`. Switching to main and pulling brought in upstream changes, causing a stash-pop conflict on `research.py`. Resolved by taking `--theirs` (the stash version), which was the intended change (context.dev removed).
