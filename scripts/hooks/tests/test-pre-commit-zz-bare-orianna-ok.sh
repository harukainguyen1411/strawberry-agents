#!/bin/sh
# xfail: T11.c of plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md
#
# Test: pre-commit-zz-plan-structure.sh must reject staged plan lines that
# carry a bare <!-- orianna: ok --> marker (no -- <reason> suffix).
#
# Cases:
#   CASE_1_BARE_MARKER_FAIL   — a staged plan line with bare <!-- orianna: ok -->
#                               (no reason) must be blocked at commit time
#   CASE_2_REASON_MARKER_PASS — a staged plan line with <!-- orianna: ok -- URL-shaped prose token (docs) -->
#                               (with reason) must be accepted
#   CASE_3_LEGACY_COMMITTED_OK — an already-committed (not staged) bare marker line
#                                must NOT be retroactively flagged (only staged lines checked)
#
# xfail guard: all three cases report xfail when the plan-structure hook does
# not yet enforce the reason-required pattern (T11.c not yet implemented).
# Detected by: HOOK does not contain "reason" keyword.
#
# Run: bash scripts/hooks/tests/test-pre-commit-zz-bare-orianna-ok.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-zz-plan-structure.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
# Detect whether the hook already enforces reason-required by checking for
# "reason" keyword in the hook script body (set by T11.c implementation).
HOOK_HAS_REASON_ENFORCEMENT=0
if [ -f "$HOOK" ] && grep -q "reason" "$HOOK" 2>/dev/null; then
  HOOK_HAS_REASON_ENFORCEMENT=1
fi

if [ "$HOOK_HAS_REASON_ENFORCEMENT" -eq 0 ]; then
  printf 'XFAIL  reason-required enforcement absent in pre-commit-zz-plan-structure.sh — all 3 cases xfail (T11.c not yet implemented)\n'
  printf 'XFAIL  CASE_1_BARE_MARKER_FAIL\n'
  printf 'XFAIL  CASE_2_REASON_MARKER_PASS\n'
  printf 'XFAIL  CASE_3_LEGACY_COMMITTED_OK\n'
  printf '\nResults: 0 passed, 3 xfail (expected — reason-required enforcement not yet implemented)\n'
  exit 0
fi

# Helper: create a minimal git repo with the hook wired
make_repo() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed/personal"
  printf '%s' "$r"
}

# write_full_plan: write a valid plan with the given body line into FILE
write_full_plan() {
  file="$1"
  body_line="$2"
  cat > "$file" << EOF
---
title: test-plan
status: proposed
concern: personal
owner: viktor
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
---

# Body

Some plan content. $body_line

## Tasks

- [ ] **T1** — Write a test. kind: test. estimate_minutes: 15.

## Test plan

Tests are not required for this fixture.
EOF
}

# run_hook: invoke the hook in the context of REPO; returns exit code
run_hook() {
  repo="$1"
  rc=0
  GIT_DIR="$repo/.git" \
  GIT_WORK_TREE="$repo" \
    bash "$HOOK" 2>/dev/null || rc=$?
  printf '%d' "$rc"
}

# --- CASE 1: Staged plan line with bare <!-- orianna: ok --> → must be BLOCKED ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/personal/2026-04-21-bare-marker.md"
write_full_plan "$PLAN" "See \`scripts/nonexistent-path.sh\` for details. <!-- orianna: ok -->"
git -C "$REPO" add "$PLAN"
rc="$(run_hook "$REPO")"
if [ "$rc" -ne 0 ]; then
  pass "CASE_1_BARE_MARKER_FAIL"
else
  fail "CASE_1_BARE_MARKER_FAIL" "expected hook to BLOCK bare orianna: ok marker; got exit 0"
fi
rm -rf "$REPO"

# --- CASE 2: Staged plan line with <!-- orianna: ok -- reason --> → must PASS ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/personal/2026-04-21-reason-marker.md"
write_full_plan "$PLAN" "See \`scripts/nonexistent-path.sh\` for details. <!-- orianna: ok -- prospective path, not yet created -->"
git -C "$REPO" add "$PLAN"
rc="$(run_hook "$REPO")"
if [ "$rc" = "0" ]; then
  pass "CASE_2_REASON_MARKER_PASS"
else
  fail "CASE_2_REASON_MARKER_PASS" "expected hook to allow orianna: ok marker with reason; got exit $rc"
fi
rm -rf "$REPO"

# --- CASE 3: Already-committed bare marker line NOT in staged diff → must PASS ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/personal/2026-04-21-legacy-bare.md"
# Commit the plan with a bare marker
write_full_plan "$PLAN" "See \`scripts/nonexistent-path.sh\` for details. <!-- orianna: ok -->"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan with legacy bare marker" 2>/dev/null || true
# Now stage only a non-marker change (title update in a different field)
# Add a new line that does NOT contain a bare marker
printf '\nExtra content added later.\n' >> "$PLAN"
# Make the additional content valid (no backtick paths without suppressors)
git -C "$REPO" add "$PLAN"
rc="$(run_hook "$REPO")"
if [ "$rc" = "0" ]; then
  pass "CASE_3_LEGACY_COMMITTED_OK"
else
  fail "CASE_3_LEGACY_COMMITTED_OK" "expected hook NOT to flag already-committed bare marker; got exit $rc"
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
