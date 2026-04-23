#!/bin/sh
# Bootstrap Orianna's git identity in the current worktree.
# Sourced (or invoked) by Orianna's agent session on every startup.
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T5
#
# Usage: . agents/orianna/memory/git-identity.sh
#   OR:  bash agents/orianna/memory/git-identity.sh

git config user.email "orianna@strawberry.local"
git config user.name "Orianna"
printf '[orianna] git identity set: orianna@strawberry.local / Orianna\n' >&2
