#!/bin/sh
# Bootstrap Orianna's git identity in the current worktree.
# Sourced (or invoked) by Orianna's agent session on every startup.
#
# Plans:
#   plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T5 (original)
#   plans/approved/personal/2026-04-25-orianna-identity-protocol-alignment.md (this update)
#
# Identity design: Orianna commits and pushes under the NEUTRAL Duongntd identity.
# Her persona signal is carried exclusively in the commit body via the
# "Promoted-By: Orianna" trailer. This satisfies Layer 3 (pre-push-resolved-identity.sh)
# on first attempt — no amend-shuffle required.
#
# Layer 2 (pre-commit-resolved-identity.sh) retains its STRAWBERRY_AGENT=orianna
# carve-out as defense-in-depth, but the carve-out is no longer load-bearing.
#
# Usage: . agents/orianna/memory/git-identity.sh
#   OR:  bash agents/orianna/memory/git-identity.sh

git config user.email "103487096+Duongntd@users.noreply.github.com"
git config user.name "Duongntd"
printf '[orianna] git identity set: neutral Duongntd (persona signal carried in Promoted-By trailer)\n' >&2
