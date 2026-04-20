#!/bin/sh
# T5.2 — xfail tests for scripts/orianna-verify-signature.sh
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T5.2
# Run: bash scripts/test-orianna-verify-signature.sh
# 6 cases: good sig, tampered body, wrong author email, missing trailer,
#          multi-file diff scope, stale sig after edit.
# All cases xfail until T2.2 (orianna-verify-signature.sh) is implemented.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$SCRIPT_DIR/orianna-verify-signature.sh"
HASH_BODY="$SCRIPT_DIR/orianna-hash-body.sh"

ORIANNA_EMAIL="orianna@agents.strawberry.local"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s\n  expected: %s\n  actual rc=%d\n' "$1" "$2" "$3"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
if [ ! -f "$VERIFY" ] || [ ! -f "$HASH_BODY" ]; then
  printf 'XFAIL  orianna-verify-signature.sh or orianna-hash-body.sh not present — all 6 cases xfail (T2.2/T1.1 not yet implemented)\n'
  for c in GOOD_SIG TAMPERED_BODY WRONG_AUTHOR MISSING_TRAILER MULTI_FILE_SCOPE STALE_SIG_AFTER_EDIT; do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 6 xfail (expected — implementation not present)\n'
  exit 0
fi

# --- Fixture helpers ---

make_repo() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed"
  printf '%s' "$r"
}

write_plan() {
  repo="$1"; slug="$2"
  f="$repo/plans/proposed/$slug.md"
  # Use printf '%s\n' for each line to avoid printf treating '---' as option flags
  printf '%s\n' "---" > "$f"
  printf '%s\n' "title: $slug" >> "$f"
  printf '%s\n' "status: proposed" >> "$f"
  printf '%s\n' "---" >> "$f"
  printf '%s\n' "" >> "$f"
  printf '%s\n' "# Body" >> "$f"
  printf '%s\n' "" >> "$f"
  printf '%s\n' "Test plan content." >> "$f"
  printf '%s' "$f"
}

compute_hash() {
  bash "$HASH_BODY" "$1"
}

add_valid_signature() {
  # Add a valid orianna_signature_approved to the plan and commit as Orianna
  plan_file="$1"; repo="$2"; phase="${3:-approved}"
  hash="$(compute_hash "$plan_file")"
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  sig="sha256:${hash}:${ts}"
  # Insert signature into frontmatter (after the first ---)
  tmp="$(mktemp)"
  awk -v sig="$sig" -v phase="$phase" '
    /^---$/ && NR > 1 { print "orianna_signature_" phase ": \"" sig "\"" }
    { print }
  ' "$plan_file" > "$tmp"
  mv "$tmp" "$plan_file"
  git -C "$repo" add "$plan_file"
  git -C "$repo" \
    -c user.email="$ORIANNA_EMAIL" \
    -c user.name="Orianna (agent)" \
    commit -q \
    -m "chore: orianna signature for $(basename "$plan_file" .md)-${phase}" \
    --trailer "Signed-by: Orianna" \
    --trailer "Signed-phase: ${phase}" \
    --trailer "Signed-hash: sha256:${hash}"
  printf '%s' "$sig"
}

# --- CASE 1: Good signature → exit 0 ---
REPO="$(make_repo)"
PLAN="$(write_plan "$REPO" "2026-04-20-test-plan")"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
add_valid_signature "$PLAN" "$REPO" "approved" >/dev/null

rc=0
bash "$VERIFY" "$PLAN" approved >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
  pass "GOOD_SIG"
else
  fail "GOOD_SIG" "exit 0" "$rc"
fi
rm -rf "$REPO"

# --- CASE 2: Tampered body → hash mismatch → non-zero ---
REPO="$(make_repo)"
PLAN="$(write_plan "$REPO" "2026-04-20-test-plan")"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
add_valid_signature "$PLAN" "$REPO" "approved" >/dev/null
# Now tamper the body after signing
printf '\nTampered line added.\n' >> "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "chore: tamper"

rc=0
bash "$VERIFY" "$PLAN" approved >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  pass "TAMPERED_BODY"
else
  fail "TAMPERED_BODY" "non-zero exit" 0
fi
rm -rf "$REPO"

# --- CASE 3: Wrong author email → non-zero ---
REPO="$(make_repo)"
PLAN="$(write_plan "$REPO" "2026-04-20-test-plan")"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
# Sign as the wrong identity
hash="$(compute_hash "$PLAN")"
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
sig="sha256:${hash}:${ts}"
tmp="$(mktemp)"
awk -v sig="$sig" '
  /^---$/ && NR > 1 { print "orianna_signature_approved: \"" sig "\"" }
  { print }
' "$PLAN" > "$tmp" && mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" \
  -c user.email="wrong@identity.example.com" \
  -c user.name="Imposter" \
  commit -q \
  -m "chore: orianna signature for test-plan-approved" \
  --trailer "Signed-by: Orianna" \
  --trailer "Signed-phase: approved" \
  --trailer "Signed-hash: sha256:${hash}"

rc=0
bash "$VERIFY" "$PLAN" approved >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  pass "WRONG_AUTHOR"
else
  fail "WRONG_AUTHOR" "non-zero exit" 0
fi
rm -rf "$REPO"

# --- CASE 4: Missing trailer → non-zero ---
REPO="$(make_repo)"
PLAN="$(write_plan "$REPO" "2026-04-20-test-plan")"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
hash="$(compute_hash "$PLAN")"
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
sig="sha256:${hash}:${ts}"
tmp="$(mktemp)"
awk -v sig="$sig" '
  /^---$/ && NR > 1 { print "orianna_signature_approved: \"" sig "\"" }
  { print }
' "$PLAN" > "$tmp" && mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"
# Commit with Orianna identity but NO trailers
git -C "$REPO" \
  -c user.email="$ORIANNA_EMAIL" \
  -c user.name="Orianna (agent)" \
  commit -q \
  -m "chore: orianna signature for test-plan-approved"

rc=0
bash "$VERIFY" "$PLAN" approved >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  pass "MISSING_TRAILER"
else
  fail "MISSING_TRAILER" "non-zero exit" 0
fi
rm -rf "$REPO"

# --- CASE 5: Multi-file diff scope in signing commit → non-zero ---
REPO="$(make_repo)"
PLAN="$(write_plan "$REPO" "2026-04-20-test-plan")"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
hash="$(compute_hash "$PLAN")"
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
sig="sha256:${hash}:${ts}"
tmp="$(mktemp)"
awk -v sig="$sig" '
  /^---$/ && NR > 1 { print "orianna_signature_approved: \"" sig "\"" }
  { print }
' "$PLAN" > "$tmp" && mv "$tmp" "$PLAN"
# Add an extra unrelated file in the same commit
printf 'extra\n' > "$REPO/extra.txt"
git -C "$REPO" add "$PLAN" "$REPO/extra.txt"
git -C "$REPO" \
  -c user.email="$ORIANNA_EMAIL" \
  -c user.name="Orianna (agent)" \
  commit -q \
  -m "chore: orianna signature for test-plan-approved" \
  --trailer "Signed-by: Orianna" \
  --trailer "Signed-phase: approved" \
  --trailer "Signed-hash: sha256:${hash}"

rc=0
bash "$VERIFY" "$PLAN" approved >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  pass "MULTI_FILE_SCOPE"
else
  fail "MULTI_FILE_SCOPE" "non-zero exit" 0
fi
rm -rf "$REPO"

# --- CASE 6: Stale sig after edit → non-zero ---
# Sign, then edit body via another commit, then verify (should fail — hash stale)
REPO="$(make_repo)"
PLAN="$(write_plan "$REPO" "2026-04-20-test-plan")"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add plan"
add_valid_signature "$PLAN" "$REPO" "approved" >/dev/null
# Now edit body content — this invalidates the hash in the signature
printf '\nAdded line after signing.\n' >> "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "chore: post-sign edit"

rc=0
bash "$VERIFY" "$PLAN" approved >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  pass "STALE_SIG_AFTER_EDIT"
else
  fail "STALE_SIG_AFTER_EDIT" "non-zero exit" 0
fi
rm -rf "$REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
