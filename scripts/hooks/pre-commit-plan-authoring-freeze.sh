#!/bin/sh
# pre-commit-plan-authoring-freeze.sh — Temporary freeze on new plan authoring.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D12, T8.1
#
# Rejects newly-ADDED (status 'A') files under plans/proposed/.
# Edits (M), renames (R), and deletes (D) pass through.
#
# This freeze is TEMPORARY. It is lifted when scripts/orianna-sign.sh,
# scripts/orianna-verify-signature.sh, and the updated plan-promote.sh
# are validated end-to-end (§D12 smoke criterion — T11.1).
#
# To lift the freeze: delete this file and remove it from install-hooks.sh.
# Commit with: chore: lift §D12 plan-authoring freeze
#
# §D12 resolution: freeze applies to new files only (Q11 — added entries only).
# Authors may still edit existing proposed drafts during the freeze window.

set -eu

REPO_ROOT="${GIT_WORK_TREE:-$(git rev-parse --show-toplevel 2>/dev/null)}"

# Check for any newly-ADDED files under plans/proposed/
NEW_PROPOSED="$(git diff --cached --name-status 2>/dev/null | awk '$1=="A" && $2 ~ /^plans\/proposed\//')"

if [ -n "$NEW_PROPOSED" ]; then
  printf '[plan-authoring-freeze] ERROR: New plan creation is frozen (§D12 of plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md).\n' >&2
  printf '\n' >&2
  printf '  New files blocked:\n' >&2
  printf '%s\n' "$NEW_PROPOSED" | while IFS= read -r line; do
    printf '    %s\n' "$line" >&2
  done
  printf '\n' >&2
  printf '  The freeze prevents new plan authoring until the Orianna gate infrastructure\n' >&2
  printf '  (orianna-sign.sh, orianna-verify-signature.sh, updated plan-promote.sh) is\n' >&2
  printf '  validated end-to-end. See §D12 for freeze criteria and lift procedure.\n' >&2
  printf '\n' >&2
  printf '  If you need to create a new plan urgently, ask Duong (admin identity) to\n' >&2
  printf '  temporarily disable this hook or use the Orianna-Bypass trailer (§D9.1).\n' >&2
  exit 1
fi

exit 0
