#!/usr/bin/env bash
# test-bootstrap-resume-sources.sh
# Regression: Test 3 & 4 — bootstrap fires on resume/clear/compact; SessionStart
# identity stable across resume when env is clean.
#
# Plan: plans/approved/personal/2026-04-25-coordinator-identity-leak-watcher-fix.md
# Test 3: bootstrap emits JSON for startup|resume|clear|compact, nothing for unknown source.
# Test 4: SessionStart hook pins identity from hint file when env is clean.
#
# XFAIL: Will fail until Task 3 (bootstrap source gate) and Task 4 launcher changes land.
# POSIX-portable bash (Rule 10).
set -eu

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO="$(pwd)"

TMPDIR_WORK="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR_WORK"; }
trap cleanup EXIT

FIXTURE_REPO="$TMPDIR_WORK/repo"
mkdir -p "$FIXTURE_REPO"
printf 'Evelynn' > "$FIXTURE_REPO/.coordinator-identity"

PASS_COUNT=0
FAIL_COUNT=0
FAILURES=""

check() {
  local label="$1"
  local got="$2"
  local expected_pattern="$3"
  if printf '%s' "$got" | grep -q "$expected_pattern"; then
    printf 'PASS: %s\n' "$label"
    PASS_COUNT=$((PASS_COUNT+1))
  else
    printf 'FAIL: %s\n' "$label" >&2
    printf '  got: %s\n' "$got" >&2
    FAIL_COUNT=$((FAIL_COUNT+1))
    FAILURES="$FAILURES $label"
  fi
}

# ────────────────────────────────────────────────────────────────
# Test 3a: bootstrap fires on startup (baseline — already worked)
# ────────────────────────────────────────────────────────────────
out="$(printf '{"source":"startup"}' | REPO_ROOT="$FIXTURE_REPO" STRAWBERRY_AGENT=Evelynn \
  bash "$REPO/scripts/hooks/inbox-watch-bootstrap.sh" 2>/dev/null)"
check "bootstrap fires on startup" "$out" "SessionStart"

# ────────────────────────────────────────────────────────────────
# Test 3b: bootstrap fires on resume (XFAIL — currently exits 0 empty)
# ────────────────────────────────────────────────────────────────
out="$(printf '{"source":"resume"}' | REPO_ROOT="$FIXTURE_REPO" STRAWBERRY_AGENT=Evelynn \
  bash "$REPO/scripts/hooks/inbox-watch-bootstrap.sh" 2>/dev/null)"
check "bootstrap fires on resume" "$out" "SessionStart"

# ────────────────────────────────────────────────────────────────
# Test 3c: bootstrap fires on clear (XFAIL)
# ────────────────────────────────────────────────────────────────
out="$(printf '{"source":"clear"}' | REPO_ROOT="$FIXTURE_REPO" STRAWBERRY_AGENT=Evelynn \
  bash "$REPO/scripts/hooks/inbox-watch-bootstrap.sh" 2>/dev/null)"
check "bootstrap fires on clear" "$out" "SessionStart"

# ────────────────────────────────────────────────────────────────
# Test 3d: bootstrap fires on compact (XFAIL)
# ────────────────────────────────────────────────────────────────
out="$(printf '{"source":"compact"}' | REPO_ROOT="$FIXTURE_REPO" STRAWBERRY_AGENT=Evelynn \
  bash "$REPO/scripts/hooks/inbox-watch-bootstrap.sh" 2>/dev/null)"
check "bootstrap fires on compact" "$out" "SessionStart"

# ────────────────────────────────────────────────────────────────
# Test 3e: bootstrap silent for unknown source
# ────────────────────────────────────────────────────────────────
out="$(printf '{"source":"unknown"}' | REPO_ROOT="$FIXTURE_REPO" STRAWBERRY_AGENT=Evelynn \
  bash "$REPO/scripts/hooks/inbox-watch-bootstrap.sh" 2>/dev/null)"
if [ -z "$out" ]; then
  printf 'PASS: bootstrap silent for unknown source\n'
  PASS_COUNT=$((PASS_COUNT+1))
else
  printf 'FAIL: bootstrap should be silent for unknown source, got: %s\n' "$out" >&2
  FAIL_COUNT=$((FAIL_COUNT+1))
  FAILURES="$FAILURES unknown-source-silent"
fi

# ────────────────────────────────────────────────────────────────
# Test 3f: bootstrap fires on resume with Tier 3 file fallback (no env) (XFAIL)
# ────────────────────────────────────────────────────────────────
out="$(printf '{"source":"resume"}' | \
  REPO_ROOT="$FIXTURE_REPO" \
  bash -c 'unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME 2>/dev/null; bash '"$REPO/scripts/hooks/inbox-watch-bootstrap.sh" \
  2>/dev/null)"
check "bootstrap fires on resume via Tier 3 file (no env)" "$out" "SessionStart"

# ────────────────────────────────────────────────────────────────
# Test 4: SessionStart identity stable via hint file when env clean
# ────────────────────────────────────────────────────────────────
# With env set — should pin Evelynn
out="$(printf '{"source":"resume"}' | \
  REPO_ROOT="$FIXTURE_REPO" STRAWBERRY_AGENT=Evelynn \
  bash "$REPO/scripts/hooks/sessionstart-coordinator-identity.sh" 2>/dev/null)"
check "SessionStart pins Evelynn with env set" "$out" "Evelynn"

# Without env set — should pin Evelynn from hint file (Tier 2 in sessionstart hook)
out="$(printf '{"source":"resume"}' | \
  REPO_ROOT="$FIXTURE_REPO" \
  bash -c 'unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME 2>/dev/null; bash '"$REPO/scripts/hooks/sessionstart-coordinator-identity.sh" \
  2>/dev/null)"
check "SessionStart pins Evelynn from hint file (no env)" "$out" "Evelynn"

# ────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
  printf 'Failed tests:%s\n' "$FAILURES" >&2
  exit 1
fi
exit 0
