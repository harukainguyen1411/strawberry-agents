#!/bin/sh
# xfail: T1 of plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md
#
# Test: body-hash pre-commit guard — four fixture cases
# Plan task: T1 (kind: test) — precedes T2 (implementation) per Rule 12.
#
# Cases:
#   CASE_1_NO_SIG_PASS      — plan with no signature fields → guard must pass (exit 0)
#   CASE_2_UNCHANGED_PASS   — signed plan committed with unchanged body → guard must pass
#   CASE_3_BODY_EDIT_FAIL   — signed plan with a one-char body edit → guard must fail with runbook error
#   CASE_4_STALE_ONE_FAIL   — plan with two signatures where one hash is stale → guard must fail,
#                             naming the stale phase
#
# xfail guard: all four cases exit-0 (reported as xfail) when the guard script
# does not yet exist (T2 not implemented).
#
# Run: bash scripts/hooks/tests/test-pre-commit-orianna-body-hash-guard.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-orianna-body-hash-guard.sh"
HASH_BODY="$REPO_ROOT/scripts/orianna-hash-body.sh"

PASS=0
FAIL=0

# --- XFAIL guard ---
if [ ! -f "$HOOK" ]; then
  printf 'XFAIL  pre-commit-orianna-body-hash-guard.sh not present — all 4 cases xfail (T2 not yet implemented)\n'
  printf 'XFAIL  CASE_1_NO_SIG_PASS\n'
  printf 'XFAIL  CASE_2_UNCHANGED_PASS\n'
  printf 'XFAIL  CASE_3_BODY_EDIT_FAIL\n'
  printf 'XFAIL  CASE_4_STALE_ONE_FAIL\n'
  printf '\nResults: 0 passed, 4 xfail (expected — implementation not present)\n'
  exit 0
fi

# Require hash-body helper too
if [ ! -f "$HASH_BODY" ]; then
  printf 'XFAIL  orianna-hash-body.sh not present — all 4 cases xfail (dependency missing)\n'
  printf 'XFAIL  CASE_1_NO_SIG_PASS\n'
  printf 'XFAIL  CASE_2_UNCHANGED_PASS\n'
  printf 'XFAIL  CASE_3_BODY_EDIT_FAIL\n'
  printf 'XFAIL  CASE_4_STALE_ONE_FAIL\n'
  printf '\nResults: 0 passed, 4 xfail (expected — dependency not present)\n'
  exit 0
fi

# Helpers
pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# make_repo: create a minimal git repo with a plan file, return its path on stdout
make_repo() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed"
  printf '%s' "$r"
}

# write_plan: write a canonical plan with frontmatter and body into FILE
write_plan() {
  file="$1"
  cat > "$file" << 'PLANEOF'
---
title: test-plan
status: proposed
---

# Body

This is the plan body content.
PLANEOF
}

# compute_body_hash: compute hash of FILE body via hash-body helper
compute_body_hash() {
  bash "$HASH_BODY" "$1"
}

# run_hook: run the guard in the context of REPO with optional author email
# Returns the exit code
run_hook() {
  repo="$1"
  author_email="${2:-test@example.com}"
  rc=0
  GIT_DIR="$repo/.git" \
  GIT_WORK_TREE="$repo" \
  GIT_AUTHOR_EMAIL="$author_email" \
    bash "$HOOK" 2>&1 || rc=$?
  printf '%d' "$rc"
}

# --- CASE 1: Plan with no orianna_signature_* field → guard must pass (exit 0) ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-no-sig.md"
write_plan "$PLAN"
git -C "$REPO" add "$PLAN"
rc="$(run_hook "$REPO")"
if [ "$rc" = "0" ]; then
  pass "CASE_1_NO_SIG_PASS"
else
  fail "CASE_1_NO_SIG_PASS" "expected exit 0 for unsigned plan; got exit $rc"
fi
rm -rf "$REPO"

# --- CASE 2: Signed plan committed with unchanged body → guard must pass (exit 0) ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-signed.md"
write_plan "$PLAN"
# Commit the unsigned plan first so we have a baseline
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
# Compute real hash of the current body
HASH="$(compute_body_hash "$PLAN")"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Add signature to frontmatter (between first two --- delimiters)
tmp="$(mktemp)"
awk -v sig="orianna_signature_approved: \"sha256:${HASH}:${TS}\"" \
  '/^---$/ && NR > 1 { print sig } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
# Stage only the signature addition — body is unchanged, hash remains valid
git -C "$REPO" add "$PLAN"
rc="$(run_hook "$REPO")"
if [ "$rc" = "0" ]; then
  pass "CASE_2_UNCHANGED_PASS"
else
  fail "CASE_2_UNCHANGED_PASS" "expected exit 0 for valid hash; got exit $rc"
fi
rm -rf "$REPO"

# --- CASE 3: Signed plan with one-char body edit → guard must fail with runbook error ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-edited.md"
write_plan "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
# Compute hash of ORIGINAL body
HASH="$(compute_body_hash "$PLAN")"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Write plan with signature referencing original hash
tmp="$(mktemp)"
awk -v sig="orianna_signature_approved: \"sha256:${HASH}:${TS}\"" \
  '/^---$/ && NR > 1 { print sig } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
# Now make a one-char body edit AFTER the signature is in place
printf '\nX\n' >> "$PLAN"
git -C "$REPO" add "$PLAN"
rc=0
output="$(GIT_DIR="$REPO/.git" GIT_WORK_TREE="$REPO" GIT_AUTHOR_EMAIL="test@example.com" \
  bash "$HOOK" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then
  # Also verify the output contains a runbook-style hint
  if printf '%s\n' "$output" | grep -qi "orianna-bypass\|runbook\|hash\|mismatch\|body"; then
    pass "CASE_3_BODY_EDIT_FAIL"
  else
    fail "CASE_3_BODY_EDIT_FAIL" "exit was non-zero but output lacked runbook hint; got: $output"
  fi
else
  fail "CASE_3_BODY_EDIT_FAIL" "expected exit non-zero for stale hash; got exit 0"
fi
rm -rf "$REPO"

# --- CASE 4: Two signatures, only one stale hash → guard must fail naming stale phase ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-21-two-sigs.md"
write_plan "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
# Compute valid hash for approved phase
HASH_GOOD="$(compute_body_hash "$PLAN")"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Use a deliberately wrong hash for in_progress phase
HASH_BAD="0000000000000000000000000000000000000000000000000000000000000000"
# Write both signatures into frontmatter
tmp="$(mktemp)"
awk -v sig_a="orianna_signature_approved: \"sha256:${HASH_GOOD}:${TS}\"" \
    -v sig_i="orianna_signature_in_progress: \"sha256:${HASH_BAD}:${TS}\"" \
  '/^---$/ && NR > 1 { print sig_a; print sig_i } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"
rc=0
output="$(GIT_DIR="$REPO/.git" GIT_WORK_TREE="$REPO" GIT_AUTHOR_EMAIL="test@example.com" \
  bash "$HOOK" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then
  # Output must name the stale phase (in_progress)
  if printf '%s\n' "$output" | grep -qi "in.progress\|in_progress"; then
    pass "CASE_4_STALE_ONE_FAIL"
  else
    fail "CASE_4_STALE_ONE_FAIL" "exit was non-zero but output did not name the stale phase; got: $output"
  fi
else
  fail "CASE_4_STALE_ONE_FAIL" "expected exit non-zero for stale in_progress hash; got exit 0"
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
