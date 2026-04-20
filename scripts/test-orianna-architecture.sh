#!/bin/sh
# T5.5 — xfail tests for scripts/_lib_orianna_architecture.sh
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T5.5
# Run: bash scripts/test-orianna-architecture.sh
# 5 cases:
#   1. both architecture_changes and architecture_impact absent → block
#   2. architecture_changes list with path not modified since approval → block
#   3. architecture_changes list with valid (modified since approval) path → pass
#   4. architecture_impact: none with empty ## Architecture impact section → block
#   5. architecture_impact: none with one-line reason → pass
# All cases xfail until T4.4 (_lib_orianna_architecture.sh) is implemented.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/_lib_orianna_architecture.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (expected: %s, got rc=%d)\n' "$1" "$2" "$3"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
if [ ! -f "$LIB" ]; then
  printf 'XFAIL  _lib_orianna_architecture.sh not present — all 5 cases xfail (T4.4 not yet implemented)\n'
  for c in BOTH_ABSENT LIST_UNMODIFIED LIST_VALID_MODS NONE_EMPTY_SECTION NONE_ONE_LINE_REASON; do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 5 xfail (expected — implementation not present)\n'
  exit 0
fi

. "$LIB"

# check_architecture_declaration <plan_file> <repo_root> <approved_timestamp>
# returns 0 on pass, non-zero on block

# --- Fixture helpers ---

make_repo_with_arch() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/architecture" "$r/plans/in-progress"
  printf 'initial arch content\n' > "$r/architecture/agent-system.md"
  git -C "$r" add .
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit -q -m "add arch file"
  printf '%s' "$r"
}

approved_ts() {
  # ISO-8601 UTC timestamp in the past (approval was 1 hour ago)
  date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
    date -u --date='1 hour ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
    printf '2026-04-20T00:00:00Z'
}

make_plan_both_absent() {
  r="$1"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  printf '---\ntitle: test\nstatus: in-progress\n---\n\n# Body\n\nContent.\n\n## Test results\n\nhttps://ci.example.com/run/123\n' > "$f"
  printf '%s' "$f"
}

make_plan_changes_list() {
  r="$1"; path="$2"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  printf '---\ntitle: test\nstatus: in-progress\narchitecture_changes:\n  - %s\n---\n\n# Body\n\nContent.\n\n## Test results\n\nhttps://ci.example.com/run/123\n' "$path" > "$f"
  printf '%s' "$f"
}

make_plan_none_empty() {
  r="$1"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  printf '---\ntitle: test\nstatus: in-progress\narchitecture_impact: none\n---\n\n# Body\n\nContent.\n\n## Architecture impact\n\n## Test results\n\nhttps://ci.example.com/run/123\n' > "$f"
  printf '%s' "$f"
}

make_plan_none_reason() {
  r="$1"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  printf '---\ntitle: test\nstatus: in-progress\narchitecture_impact: none\n---\n\n# Body\n\nContent.\n\n## Architecture impact\n\nNone. This plan migrates one script'\''s error messages only.\n\n## Test results\n\nhttps://ci.example.com/run/123\n' > "$f"
  printf '%s' "$f"
}

TS="$(approved_ts)"

# --- CASE 1: Both fields absent → block ---
REPO="$(make_repo_with_arch)"
PLAN="$(make_plan_both_absent "$REPO")"
rc=0; check_architecture_declaration "$PLAN" "$REPO" "$TS" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "BOTH_ABSENT"; else fail "BOTH_ABSENT" "non-zero" 0; fi
rm -rf "$REPO"

# --- CASE 2: architecture_changes list but path not modified since approval → block ---
REPO="$(make_repo_with_arch)"
# Do NOT modify architecture/agent-system.md after repo creation (simulates no post-approval change)
PLAN="$(make_plan_changes_list "$REPO" "architecture/agent-system.md")"
rc=0; check_architecture_declaration "$PLAN" "$REPO" "$TS" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "LIST_UNMODIFIED"; else fail "LIST_UNMODIFIED" "non-zero" 0; fi
rm -rf "$REPO"

# --- CASE 3: architecture_changes list with path modified after approval → pass ---
REPO="$(make_repo_with_arch)"
# Modify the arch file AFTER the "approved" timestamp
printf '\nupdated content\n' >> "$REPO/architecture/agent-system.md"
git -C "$REPO" add .
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "chore: update arch doc"
PLAN="$(make_plan_changes_list "$REPO" "architecture/agent-system.md")"
rc=0; check_architecture_declaration "$PLAN" "$REPO" "$TS" 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "LIST_VALID_MODS"; else fail "LIST_VALID_MODS" "exit 0" "$rc"; fi
rm -rf "$REPO"

# --- CASE 4: architecture_impact: none with empty ## Architecture impact section → block ---
REPO="$(make_repo_with_arch)"
PLAN="$(make_plan_none_empty "$REPO")"
rc=0; check_architecture_declaration "$PLAN" "$REPO" "$TS" 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "NONE_EMPTY_SECTION"; else fail "NONE_EMPTY_SECTION" "non-zero" 0; fi
rm -rf "$REPO"

# --- CASE 5: architecture_impact: none with one-line reason → pass ---
REPO="$(make_repo_with_arch)"
PLAN="$(make_plan_none_reason "$REPO")"
rc=0; check_architecture_declaration "$PLAN" "$REPO" "$TS" 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "NONE_ONE_LINE_REASON"; else fail "NONE_ONE_LINE_REASON" "exit 0" "$rc"; fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
