#!/usr/bin/env bash
# test-coordinator-boot-identity-export.sh — xfail test for AC-4 / INV-4 / INV-5.
#
# After coordinator-boot.sh Evelynn runs (with claude exec stubbed),
# the exported env vars must be:
#   CLAUDE_AGENT_NAME=Evelynn
#   STRAWBERRY_AGENT=Evelynn
#   STRAWBERRY_CONCERN=personal
# Same for Sona/work.
#
# Plan: 2026-04-24-coordinator-boot-unification (T10)
# xfail property: test PASSES once coordinator-boot.sh exists and exports
#   correct vars; will FAIL if coordinator-boot.sh is reverted or removed.
#   C1 already provides the script, so this test is "green" against C1+.
#   It remains a regression guard.
#
# Exit 0 = all assertions pass; exit 1 = assertion failure.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BOOT="$REPO_ROOT/scripts/coordinator-boot.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT+1)); }

FAIL_COUNT=0

# Guard: boot script must exist
if [ ! -f "$BOOT" ]; then
  printf '[XFAIL] coordinator-boot.sh does not exist — expected after C1\n' >&2
  exit 1
fi
if [ ! -x "$BOOT" ]; then
  printf '[XFAIL] coordinator-boot.sh is not executable\n' >&2
  exit 1
fi

# Create a stub claude binary that just dumps env to a tmpfile then exits.
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT INT TERM

STUB_BIN="$TMPDIR_TEST/claude"
ENV_OUT_EVELYNN="$TMPDIR_TEST/env-evelynn.txt"
ENV_OUT_SONA="$TMPDIR_TEST/env-sona.txt"

cat > "$STUB_BIN" <<'STUB'
#!/bin/sh
# Dump env and exit (simulates the 'exec claude' step)
env > "$ENV_OUT"
exit 0
STUB
chmod +x "$STUB_BIN"

# Also stub memory-consolidate.sh to avoid real side-effects
SCRIPTS_DIR="$REPO_ROOT/scripts"
STUB_CONSOLIDATE="$TMPDIR_TEST/memory-consolidate.sh"
cat > "$STUB_CONSOLIDATE" <<'STUB'
#!/bin/sh
exit 0
STUB
chmod +x "$STUB_CONSOLIDATE"

# ── Test 1: Evelynn identity export ──────────────────────────────────────────

ENV_OUT="$ENV_OUT_EVELYNN" \
  PATH="$TMPDIR_TEST:$PATH" \
  bash "$BOOT" Evelynn 2>/dev/null || true

# Check env file was created by stub
if [ ! -f "$ENV_OUT_EVELYNN" ]; then
  fail "Evelynn: claude stub did not run (env file missing)"
else
  if grep -q 'CLAUDE_AGENT_NAME=Evelynn' "$ENV_OUT_EVELYNN"; then
    pass "Evelynn: CLAUDE_AGENT_NAME=Evelynn exported"
  else
    fail "Evelynn: CLAUDE_AGENT_NAME not set to Evelynn. Got: $(grep CLAUDE_AGENT_NAME "$ENV_OUT_EVELYNN" || echo '(not set)')"
  fi

  if grep -q 'STRAWBERRY_AGENT=Evelynn' "$ENV_OUT_EVELYNN"; then
    pass "Evelynn: STRAWBERRY_AGENT=Evelynn exported"
  else
    fail "Evelynn: STRAWBERRY_AGENT not set to Evelynn"
  fi

  if grep -q 'STRAWBERRY_CONCERN=personal' "$ENV_OUT_EVELYNN"; then
    pass "Evelynn: STRAWBERRY_CONCERN=personal exported"
  else
    fail "Evelynn: STRAWBERRY_CONCERN not set to personal"
  fi
fi

# ── Test 2: Sona identity export ─────────────────────────────────────────────

ENV_OUT="$ENV_OUT_SONA" \
  PATH="$TMPDIR_TEST:$PATH" \
  bash "$BOOT" Sona 2>/dev/null || true

if [ ! -f "$ENV_OUT_SONA" ]; then
  fail "Sona: claude stub did not run (env file missing)"
else
  if grep -q 'CLAUDE_AGENT_NAME=Sona' "$ENV_OUT_SONA"; then
    pass "Sona: CLAUDE_AGENT_NAME=Sona exported"
  else
    fail "Sona: CLAUDE_AGENT_NAME not set to Sona"
  fi

  if grep -q 'STRAWBERRY_AGENT=Sona' "$ENV_OUT_SONA"; then
    pass "Sona: STRAWBERRY_AGENT=Sona exported"
  else
    fail "Sona: STRAWBERRY_AGENT not set to Sona"
  fi

  if grep -q 'STRAWBERRY_CONCERN=work' "$ENV_OUT_SONA"; then
    pass "Sona: STRAWBERRY_CONCERN=work exported"
  else
    fail "Sona: STRAWBERRY_CONCERN not set to work"
  fi
fi

# ── Test 3: bad arg exits 2 ──────────────────────────────────────────────────

RC=0
PATH="$TMPDIR_TEST:$PATH" bash "$BOOT" BadName 2>/dev/null || RC=$?
if [ "$RC" -eq 2 ]; then
  pass "BadName: exits 2"
else
  fail "BadName: expected exit 2, got $RC"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] coordinator-boot identity-export assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed.\n' "$FAIL_COUNT" >&2
  exit 1
fi
