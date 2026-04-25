#!/bin/sh
# scripts/worktree-add.sh — thin wrapper around git worktree add
#
# Enforces that core.hooksPath is set before creating a worktree, ensuring
# all worktrees share the in-repo hook dispatchers automatically.
#
# Usage: bash scripts/worktree-add.sh <path> [<commit-ish>] [git-worktree-add options...]
#   e.g. bash scripts/worktree-add.sh /tmp/my-worktree -b my-branch
#
# Replaces raw: git worktree add <path> [options]
# Docs: plans/approved/personal/2026-04-25-worktree-hooks-propagation.md T4

set -e

if [ $# -eq 0 ]; then
  printf 'Usage: bash scripts/worktree-add.sh <path> [git worktree add options...]\n' >&2
  exit 1
fi

# Verify core.hooksPath is configured at the repo level (local or worktree config).
# We check --local so that a global gitconfig setting doesn't mask a missing repo config.
# The repo-local value is what guarantees hooks propagate to ALL worktrees of this clone.
hooks_path="$(git config --local core.hooksPath 2>/dev/null || echo '')"
if [ -z "$hooks_path" ]; then
  printf '[worktree-add] ERROR: core.hooksPath is not set in this repo.\n' >&2
  printf '[worktree-add] Run "bash scripts/install-hooks.sh" first to configure hooks for all worktrees.\n' >&2
  exit 1
fi

# Create the worktree, passing all arguments through.
git worktree add "$@"

printf '[worktree-add] Worktree created. Hooks are inherited via core.hooksPath = %s\n' "$hooks_path"
