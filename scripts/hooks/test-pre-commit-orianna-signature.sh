#!/bin/sh
# T5.3 — xfail tests for scripts/hooks/pre-commit-orianna-signature-guard.sh
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T5.3
# Run: bash scripts/hooks/test-pre-commit-orianna-signature.sh
# Structure mirrors scripts/hooks/test-plan-promote-guard.sh
# 4 cases: valid signing commit accept, multi-file reject, missing trailer reject,
#          extra content change reject (non-signature diff in Orianna commit).
# All cases xfail until T2.3 (pre-commit-orianna-signature-guard.sh) is implemented.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/pre-commit-orianna-signature-guard.sh"

ORIANNA_EMAIL="orianna@agents.strawberry.local"

PASS=0
FAIL=0

# --- XFAIL guard ---
if [ ! -f "$HOOK" ]; then
  printf 'XFAIL  pre-commit-orianna-signature-guard.sh not present — all 4 cases xfail (T2.3 not yet implemented)\n'
  for c in VALID_ACCEPT MULTI_FILE_REJECT MISSING_TRAILER_REJECT EXTRA_CONTENT_REJECT; do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 4 xfail (expected — implementation not present)\n'
  exit 0
fi

make_repo() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed"
  # Use heredoc to avoid printf treating '---' as option flags
  cat > "$r/plans/proposed/2026-04-20-sig-test.md" << 'PLANEOF'
---
title: test
status: proposed
---

# Body

Content.
PLANEOF
  git -C "$r" add plans/
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit -q -m "add plan"
  printf '%s' "$r"
}

run_hook() {
  repo="$1"
  msg="${2:-}"
  author_email="${3:-$ORIANNA_EMAIL}"
  if [ -n "$msg" ]; then
    printf '%s\n' "$msg" > "$repo/.git/COMMIT_EDITMSG"
  fi
  GIT_DIR="$repo/.git" \
  GIT_WORK_TREE="$repo" \
  GIT_AUTHOR_EMAIL="$author_email" \
    bash "$HOOK" 2>&1
}

# --- CASE 1: Valid signing commit — one plan file, signature line only, all trailers → ACCEPT ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-20-sig-test.md"
HASH="abc123def456"  # synthetic hash for hook shape test
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
SIG_LINE="orianna_signature_approved: \"sha256:${HASH}:${ts}\""
# Stage only the signature addition (append to frontmatter before closing ---)
tmp="$(mktemp)"
awk -v line="$SIG_LINE" '/^---$/ && NR > 1 { print line } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"

COMMIT_MSG="chore: orianna signature for 2026-04-20-sig-test-approved
Signed-by: Orianna
Signed-phase: approved
Signed-hash: sha256:${HASH}"

rc=0; output="$(run_hook "$REPO" "$COMMIT_MSG" "$ORIANNA_EMAIL" 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'PASS  VALID_ACCEPT\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  VALID_ACCEPT: expected exit 0, got %d\n' "$rc"
  printf '%s\n' "$output"
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- CASE 2: Multi-file diff in Orianna commit → REJECT ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-20-sig-test.md"
HASH="abc123def456"
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
SIG_LINE="orianna_signature_approved: \"sha256:${HASH}:${ts}\""
tmp="$(mktemp)"
awk -v line="$SIG_LINE" '/^---$/ && NR > 1 { print line } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
# Also stage an extra unrelated file
printf 'extra\n' > "$REPO/extra.txt"
git -C "$REPO" add "$PLAN" "$REPO/extra.txt"

COMMIT_MSG="chore: orianna signature for 2026-04-20-sig-test-approved
Signed-by: Orianna
Signed-phase: approved
Signed-hash: sha256:${HASH}"

rc=0; output="$(run_hook "$REPO" "$COMMIT_MSG" "$ORIANNA_EMAIL" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'PASS  MULTI_FILE_REJECT\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  MULTI_FILE_REJECT: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- CASE 3: Missing trailer in Orianna commit → REJECT ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-20-sig-test.md"
HASH="abc123def456"
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
SIG_LINE="orianna_signature_approved: \"sha256:${HASH}:${ts}\""
tmp="$(mktemp)"
awk -v line="$SIG_LINE" '/^---$/ && NR > 1 { print line } { print }' "$PLAN" > "$tmp"
mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"

# Commit message with NO trailers at all
COMMIT_MSG="chore: orianna signature for 2026-04-20-sig-test-approved"

rc=0; output="$(run_hook "$REPO" "$COMMIT_MSG" "$ORIANNA_EMAIL" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'PASS  MISSING_TRAILER_REJECT\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  MISSING_TRAILER_REJECT: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

# --- CASE 4: Extra non-signature content change in signing commit → REJECT ---
REPO="$(make_repo)"
PLAN="$REPO/plans/proposed/2026-04-20-sig-test.md"
HASH="abc123def456"
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
SIG_LINE="orianna_signature_approved: \"sha256:${HASH}:${ts}\""
# Modify the plan body AND add the signature — more than just signature addition
tmp="$(mktemp)"
awk -v line="$SIG_LINE" '/^---$/ && NR > 1 { print line } { print }' "$PLAN" > "$tmp"
printf '\nExtra body paragraph sneaked in.\n' >> "$tmp"
mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"

COMMIT_MSG="chore: orianna signature for 2026-04-20-sig-test-approved
Signed-by: Orianna
Signed-phase: approved
Signed-hash: sha256:${HASH}"

rc=0; output="$(run_hook "$REPO" "$COMMIT_MSG" "$ORIANNA_EMAIL" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'PASS  EXTRA_CONTENT_REJECT\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL  EXTRA_CONTENT_REJECT: expected non-zero exit, got 0\n'
  FAIL=$((FAIL + 1))
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
