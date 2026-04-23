#!/bin/sh
# xfail: T3 of plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md
#
# Test: extended signature guard — shape B (Signed-Fix) cases
# Plan task: T3 (kind: test) — precedes T4 (implementation) per Rule 12.
#
# Cases:
#   CASE_1_SHAPE_A_PASS         — shape A sig-only commit still passes (regression guard)
#   CASE_2_SHAPE_B_MATCH_PASS   — shape B commit with Signed-Fix: approved trailer and hash match → pass
#   CASE_3_SHAPE_B_MISMATCH_FAIL — shape B commit with Signed-Fix: approved trailer but mismatched body hash → fail
#   CASE_4_SHAPE_B_TWO_FILES_FAIL — shape B commit touching two files → fail
#
# xfail guard: cases 2–4 fail against the unchanged guard (T4 not yet implemented),
# so when the guard does not yet support Signed-Fix the test exits 0 reporting xfail
# for all four cases to maintain a clean pre-push gate.
#
# Run: bash scripts/hooks/tests/test-pre-commit-orianna-signature-guard-signed-fix.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-orianna-signature-guard.sh"
HASH_BODY="$REPO_ROOT/scripts/orianna-hash-body.sh"

ORIANNA_EMAIL="orianna@agents.strawberry.local"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
# Shape-B support requires T4 implementation. Detect whether the hook already
# accepts Signed-Fix by probing for the keyword in the script body.
HOOK_SUPPORTS_SIGNED_FIX=0
if [ -f "$HOOK" ] && grep -q "Signed-Fix" "$HOOK" 2>/dev/null; then
  HOOK_SUPPORTS_SIGNED_FIX=1
fi

if [ "$HOOK_SUPPORTS_SIGNED_FIX" -eq 0 ]; then
  printf 'XFAIL  Signed-Fix support absent in pre-commit-orianna-signature-guard.sh — all 4 cases xfail (T4 not yet implemented)\n'
  printf 'XFAIL  CASE_1_SHAPE_A_PASS\n'
  printf 'XFAIL  CASE_2_SHAPE_B_MATCH_PASS\n'
  printf 'XFAIL  CASE_3_SHAPE_B_MISMATCH_FAIL\n'
  printf 'XFAIL  CASE_4_SHAPE_B_TWO_FILES_FAIL\n'
  printf '\nResults: 0 passed, 4 xfail (expected — Signed-Fix support not yet implemented)\n'
  exit 0
fi

# Also need hash-body for shape B cases
if [ ! -f "$HASH_BODY" ]; then
  printf 'XFAIL  orianna-hash-body.sh not present — all 4 cases xfail (dependency missing)\n'
  printf 'XFAIL  CASE_1_SHAPE_A_PASS\n'
  printf 'XFAIL  CASE_2_SHAPE_B_MATCH_PASS\n'
  printf 'XFAIL  CASE_3_SHAPE_B_MISMATCH_FAIL\n'
  printf 'XFAIL  CASE_4_SHAPE_B_TWO_FILES_FAIL\n'
  printf '\nResults: 0 passed, 4 xfail (expected — dependency not present)\n'
  exit 0
fi

# Helper: create minimal git repo
make_repo() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed"
  printf '%s' "$r"
}

# write_plan: write a plan with body content into FILE
write_plan() {
  file="$1"
  cat > "$file" << 'PLANEOF'
---
title: signed-fix-test
status: proposed
---

# Body

Shape B test plan body.
PLANEOF
}

# run_hook: invoke the guard in the context of REPO with given COMMIT_EDITMSG content
# echoes the exit code
run_hook() {
  repo="$1"
  msg="$2"
  author_email="${3:-$ORIANNA_EMAIL}"
  printf '%s\n' "$msg" > "$repo/.git/COMMIT_EDITMSG"
  rc=0
  GIT_DIR="$repo/.git" \
  GIT_WORK_TREE="$repo" \
  GIT_AUTHOR_EMAIL="$author_email" \
    bash "$HOOK" 2>&1 || rc=$?
  printf '%d' "$rc"
}

# --- CASE 1: Shape A — sig-only commit still passes ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-shape-a.md"
write_plan "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
HASH="abc123def456abc123def456abc123def456abc123def456abc123def456abc1"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
SIG_LINE="orianna_signature_approved: \"sha256:${HASH}:${TS}\""
tmp="$(mktemp)"
awk -v sig="$SIG_LINE" '/^---$/ && NR > 1 { print sig } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"
MSG="chore: orianna signature for 2026-04-21-shape-a-approved
Signed-by: Orianna
Signed-phase: approved
Signed-hash: sha256:${HASH}"
rc="$(run_hook "$REPO" "$MSG")"
if [ "$rc" = "0" ]; then
  pass "CASE_1_SHAPE_A_PASS"
else
  fail "CASE_1_SHAPE_A_PASS" "shape A signing commit should still pass; got exit $rc"
fi
rm -rf "$REPO"

# --- CASE 2: Shape B — Signed-Fix: approved trailer + hash match → pass ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-shape-b-match.md"
write_plan "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
# Pre-fix rewrites BODY — compute hash AFTER any body modification
# Simulate a pre-fix rewrite: append an orianna: ok suppressor
printf '<!-- orianna: ok -- URL-shaped prose token -->\n' >> "$PLAN"
HASH="$(bash "$HASH_BODY" "$PLAN")"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Insert signature into frontmatter
tmp="$(mktemp)"
awk -v sig="orianna_signature_approved: \"sha256:${HASH}:${TS}\"" \
  '/^---$/ && NR > 1 { print sig } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"
# Shape B commit message carries Signed-Fix trailer
MSG="chore: orianna signature for 2026-04-21-shape-b-match-approved

Signed-Fix: approved
Signed-by: Orianna
Signed-phase: approved
Signed-hash: sha256:${HASH}"
rc="$(run_hook "$REPO" "$MSG")"
if [ "$rc" = "0" ]; then
  pass "CASE_2_SHAPE_B_MATCH_PASS"
else
  fail "CASE_2_SHAPE_B_MATCH_PASS" "shape B with matching hash should pass; got exit $rc"
fi
rm -rf "$REPO"

# --- CASE 3: Shape B — Signed-Fix: approved trailer but mismatched body hash → fail ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-shape-b-mismatch.md"
write_plan "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
# Compute hash of ORIGINAL body (before any edit)
HASH_REAL="$(bash "$HASH_BODY" "$PLAN")"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Insert signature claiming the original hash
tmp="$(mktemp)"
awk -v sig="orianna_signature_approved: \"sha256:${HASH_REAL}:${TS}\"" \
  '/^---$/ && NR > 1 { print sig } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
# Then make a body change AFTER signature insertion — hash now mismatches
printf '\nExtra paragraph added after signing.\n' >> "$PLAN"
git -C "$REPO" add "$PLAN"
MSG="chore: orianna signature for 2026-04-21-shape-b-mismatch-approved

Signed-Fix: approved
Signed-by: Orianna
Signed-phase: approved
Signed-hash: sha256:${HASH_REAL}"
rc="$(run_hook "$REPO" "$MSG")"
if [ "$rc" -ne 0 ]; then
  pass "CASE_3_SHAPE_B_MISMATCH_FAIL"
else
  fail "CASE_3_SHAPE_B_MISMATCH_FAIL" "shape B with mismatched hash should fail; got exit 0"
fi
rm -rf "$REPO"

# --- CASE 4: Shape B — commit touching two files → fail ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-shape-b-two-files.md"
PLAN2="$REPO/plans/proposed/2026-04-21-shape-b-second.md"
write_plan "$PLAN"
write_plan "$PLAN2"
git -C "$REPO" add "$PLAN" "$PLAN2"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plans"
HASH="$(bash "$HASH_BODY" "$PLAN")"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Add signature to first plan
tmp="$(mktemp)"
awk -v sig="orianna_signature_approved: \"sha256:${HASH}:${TS}\"" \
  '/^---$/ && NR > 1 { print sig } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
# Touch second plan (minor body edit)
printf '\nSecond plan addition.\n' >> "$PLAN2"
# Stage BOTH files
git -C "$REPO" add "$PLAN" "$PLAN2"
MSG="chore: orianna signature for 2026-04-21-shape-b-two-files-approved

Signed-Fix: approved
Signed-by: Orianna
Signed-phase: approved
Signed-hash: sha256:${HASH}"
rc="$(run_hook "$REPO" "$MSG")"
if [ "$rc" -ne 0 ]; then
  pass "CASE_4_SHAPE_B_TWO_FILES_FAIL"
else
  fail "CASE_4_SHAPE_B_TWO_FILES_FAIL" "shape B touching two files should fail; got exit 0"
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
