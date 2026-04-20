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

PAST_DATE="2026-01-01T00:00:00+0000"

make_repo_with_arch() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  # Force all initial commits to a fixed past date so that approved_ts (= NOW)
  # is always strictly after them. This ensures LIST_UNMODIFIED works correctly
  # without any same-second precision problems.
  GIT_COMMITTER_DATE="$PAST_DATE" GIT_AUTHOR_DATE="$PAST_DATE" \
    git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init" --date="$PAST_DATE"
  mkdir -p "$r/architecture" "$r/plans/in-progress"
  printf 'initial arch content\n' > "$r/architecture/agent-system.md"
  git -C "$r" add .
  GIT_COMMITTER_DATE="$PAST_DATE" GIT_AUTHOR_DATE="$PAST_DATE" \
    git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit -q -m "add arch file" --date="$PAST_DATE"
  printf '%s' "$r"
}

approved_ts() {
  # Return current UTC timestamp as the "approval" timestamp.
  # make_repo_with_arch forces its commits to PAST_DATE (2026-01-01), so this
  # timestamp (today) is always strictly after the initial repo commits.
  # Cases that need a "post-approval" arch modification commit use real current
  # time (no --date override), which is also after this TS.
  # Cases that need "no post-approval" modification simply don't add any commits.
  date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
    printf '2026-04-20T00:00:00Z'
}

make_plan_both_absent() {
  r="$1"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  cat > "$f" << 'PLANEOF'
---
title: test
status: in-progress
---

# Body

Content.

## Test results

https://ci.example.com/run/123
PLANEOF
  printf '%s' "$f"
}

make_plan_changes_list() {
  r="$1"; path="$2"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  # Write frontmatter with dynamic path using printf '%s'
  printf '%s\n' "---" > "$f"
  printf '%s\n' "title: test" >> "$f"
  printf '%s\n' "status: in-progress" >> "$f"
  printf '%s\n' "architecture_changes:" >> "$f"
  printf '  - %s\n' "$path" >> "$f"
  cat >> "$f" << 'PLANEOF'
---

# Body

Content.

## Test results

https://ci.example.com/run/123
PLANEOF
  printf '%s' "$f"
}

make_plan_none_empty() {
  r="$1"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  cat > "$f" << 'PLANEOF'
---
title: test
status: in-progress
architecture_impact: none
---

# Body

Content.

## Architecture impact

## Test results

https://ci.example.com/run/123
PLANEOF
  printf '%s' "$f"
}

make_plan_none_reason() {
  r="$1"
  f="$r/plans/in-progress/2026-04-20-test-plan.md"
  cat > "$f" << 'PLANEOF'
---
title: test
status: in-progress
architecture_impact: none
---

# Body

Content.

## Architecture impact

None. This plan migrates one script's error messages only.

## Test results

https://ci.example.com/run/123
PLANEOF
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
