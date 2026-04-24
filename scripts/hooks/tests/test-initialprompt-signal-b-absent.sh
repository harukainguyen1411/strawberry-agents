#!/usr/bin/env bash
# test-initialprompt-signal-b-absent.sh — xfail test for AC-8 / INV-2.
#
# Asserts:
#   1. The model-level resume heuristic paragraph ("If this is a resumed
#      session ... skip the file reads") is ABSENT from both agent files.
#   2. The string "skip the file reads" does not appear in either initialPrompt.
#
# XFAIL against C1 HEAD: Signal B is still present in both agent files.
# Will pass after C3/T19 (evelynn.md) and C3/T20 (sona.md).
#
# Plan: 2026-04-24-coordinator-boot-unification (T15)
# Exit 0 = pass; exit 1 = fail (xfail on C1/C2).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
EVELYNN_MD="$REPO_ROOT/.claude/agents/evelynn.md"
SONA_MD="$REPO_ROOT/.claude/agents/sona.md"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT+1)); }
FAIL_COUNT=0

for agent_file in "$EVELYNN_MD" "$SONA_MD"; do
  label="$(basename "$agent_file")"

  if [ ! -f "$agent_file" ]; then
    fail "$label: file not found at $agent_file"
    continue
  fi

  # Assertion 1: "skip the file reads entirely" must NOT appear in the file
  if grep -q 'skip the file reads entirely' "$agent_file"; then
    fail "$label: Signal B heuristic 'skip the file reads entirely' still present (xfail expected)"
  else
    pass "$label: 'skip the file reads entirely' absent"
  fi

  # Assertion 2: the specific Signal B trigger phrase must NOT appear
  if grep -q 'If this is a resumed session' "$agent_file"; then
    fail "$label: Signal B trigger 'If this is a resumed session' still present (xfail expected)"
  else
    pass "$label: 'If this is a resumed session' model heuristic absent"
  fi

  # Assertion 3: "Do NOT re-read the files" (Signal B continuation) must NOT appear
  if grep -q 'Do NOT re-read the files' "$agent_file"; then
    fail "$label: Signal B phrase 'Do NOT re-read the files' still present"
  else
    pass "$label: 'Do NOT re-read the files' phrase absent"
  fi

  # Assertion 4 (AC-8 structural): memory-consolidate.sh must NOT be in initialPrompt
  # (it moves to coordinator-boot.sh in C3). After C3 the agent file should not
  # contain the memory-consolidate invocation in its initialPrompt block.
  if grep -q 'memory-consolidate.sh' "$agent_file"; then
    fail "$label: memory-consolidate.sh still in initialPrompt — should move to coordinator-boot.sh (xfail expected)"
  else
    pass "$label: memory-consolidate.sh absent from initialPrompt (moved to boot script)"
  fi
done

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] initialPrompt Signal B absent assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on C1/C2 HEAD).\n' "$FAIL_COUNT" >&2
  exit 1
fi
