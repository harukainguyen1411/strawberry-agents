#!/bin/sh
# T5.7 + T7.2 — xfail end-to-end smoke harness + offline-fail test
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §T5.7, §T7.2
# Run: bash scripts/test-orianna-lifecycle-smoke.sh
#
# Scenario (T5.7):
#   1. Create toy plan in plans/proposed/
#   2. Sign approved (orianna-sign.sh)
#   3. Verify approved signature (orianna-verify-signature.sh)
#   4. Edit body; re-sign approved (stale sig invalidated then re-signed)
#   5. Sign in-progress (orianna-sign.sh)
#   6. Promote to in-progress (plan-promote.sh)
#   7. Sign implemented (orianna-sign.sh)
#   8. Promote to implemented (plan-promote.sh)
#   9. Verify all three signatures valid post-hoc
#
# Offline-fail test (T7.2):
#   10. With claude CLI absent from PATH, orianna-sign.sh exits non-zero
#       with "signature unavailable" message
#
# All cases xfail until T1-T6 implementation is complete.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIGN="$SCRIPT_DIR/orianna-sign.sh"
VERIFY="$SCRIPT_DIR/orianna-verify-signature.sh"
PROMOTE="$SCRIPT_DIR/plan-promote.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard: implementations not present yet ---
MISSING=""
[ ! -f "$SIGN" ]    && MISSING="$MISSING orianna-sign.sh"
[ ! -f "$VERIFY" ]  && MISSING="$MISSING orianna-verify-signature.sh"
[ ! -f "$PROMOTE" ] && MISSING="$MISSING plan-promote.sh"

if [ -n "$MISSING" ]; then
  printf 'XFAIL  Required scripts missing:%s — all smoke cases xfail (T1-T6 not yet implemented)\n' "$MISSING"
  for c in \
    APPROVED_SIGN \
    APPROVED_VERIFY \
    EDIT_STALE_DETECT \
    RESIGN_AFTER_EDIT \
    PROMOTE_TO_APPROVED \
    INPROGRESS_SIGN \
    PROMOTE_TO_INPROGRESS \
    IMPLEMENTED_SIGN \
    PROMOTE_TO_IMPLEMENTED \
    POSTHOC_ALL_SIGS_VALID \
    OFFLINE_FAIL_T7_2
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 11 xfail (expected — implementation not present)\n'
  exit 0
fi

# --- Smoke repo setup ---
# Derive real repo root from script location (always the real strawberry-agents repo).
REAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO="$(mktemp -d)"
git -C "$REPO" init -q
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit --allow-empty -q -m "init"
mkdir -p "$REPO/plans/proposed" "$REPO/plans/approved" \
  "$REPO/plans/in-progress" "$REPO/plans/implemented" \
  "$REPO/assessments/plan-fact-checks" \
  "$REPO/architecture"
printf 'arch content\n' > "$REPO/architecture/key-scripts.md"
# Copy orianna agent files so orianna-sign.sh can find prompts and contract files
# when operating with REPO=$REPO (temp repo). These are read-only references.
mkdir -p "$REPO/agents/orianna/prompts"
cp "$REAL_REPO/agents/orianna/prompts/plan-check.md" "$REPO/agents/orianna/prompts/"
cp "$REAL_REPO/agents/orianna/prompts/task-gate-check.md" "$REPO/agents/orianna/prompts/"
cp "$REAL_REPO/agents/orianna/prompts/implementation-gate-check.md" "$REPO/agents/orianna/prompts/"
cp "$REAL_REPO/agents/orianna/claim-contract.md" "$REPO/agents/orianna/"
cp "$REAL_REPO/agents/orianna/allowlist.md" "$REPO/agents/orianna/"
git -C "$REPO" add .
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "scaffold"

SLUG="2026-04-20-smoke-test-plan"
PLAN="$REPO/plans/proposed/$SLUG.md"

# Toy plan — conforming to gate-v2 rules.
# No backtick file-path claims to avoid claim-contract blocks in the approved gate.
cat > "$PLAN" << 'PLANEOF'
---
title: Smoke Test Plan
status: proposed
owner: vi
created: 2026-04-20
tags: [test, smoke]
tests_required: true
orianna_gate_version: 2
architecture_impact: none
---

# Context

Toy plan used as an end-to-end smoke fixture for the Orianna signing lifecycle.
No implementation — this plan exists only to exercise the gate infrastructure.

## Architecture impact

None. This plan exercises the signing lifecycle only; no architecture changes.

## Tasks

- [ ] **T1. Write smoke assertions.** `kind: test` | `estimate_minutes: 10`
  - detail: smoke test assertions for signing flow

- [ ] **T2. Implement smoke helper.** `kind: impl` | `estimate_minutes: 15`
  - detail: minimal implementation to support smoke assertions

## Test plan

Smoke harness covers all three phase signatures and post-hoc verification.

## Test results

https://ci.example.com/run/smoke-001
PLANEOF

git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add smoke test plan"

# --- CASE 1: Sign approved ---
rc=0
REPO="$REPO" bash "$SIGN" "$PLAN" approved 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "APPROVED_SIGN"; else fail "APPROVED_SIGN" "orianna-sign.sh approved exited $rc"; fi

# --- CASE 2: Verify approved signature ---
rc=0
bash "$VERIFY" "$PLAN" approved 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "APPROVED_VERIFY"; else fail "APPROVED_VERIFY" "verify approved exited $rc"; fi

# --- CASE 3: Edit body — signature now stale; verify should fail ---
printf '\n<!-- edit after signing -->\n' >> "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "chore: post-sign body edit"
rc=0
bash "$VERIFY" "$PLAN" approved 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ]; then pass "EDIT_STALE_DETECT"; else fail "EDIT_STALE_DETECT" "expected stale sig to be detected"; fi

# --- CASE 4: Re-sign approved after edit ---
# orianna-sign.sh's idempotency guard prevents re-signing if the field already exists.
# Remove the stale orianna_signature_approved line first (as per §D9.4 workflow),
# then commit the removal, then re-sign.
tmp="$(mktemp)"
grep -v '^orianna_signature_approved:' "$PLAN" > "$tmp" && mv "$tmp" "$PLAN"
git -C "$REPO" add "$PLAN"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "chore: remove stale approved signature before re-sign"
rc=0
REPO="$REPO" bash "$SIGN" "$PLAN" approved 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "RESIGN_AFTER_EDIT"; else fail "RESIGN_AFTER_EDIT" "re-sign approved exited $rc"; fi

# --- CASE 5: Promote to approved (proposed → approved) ---
# The plan must be in plans/approved/ before it can be signed for in_progress.
rc=0
REPO="$REPO" NO_PUSH=1 bash "$PROMOTE" "$PLAN" approved 2>/dev/null || rc=$?
APPROVED_PLAN="$REPO/plans/approved/$SLUG.md"
if [ "$rc" -eq 0 ] && [ -f "$APPROVED_PLAN" ]; then
  pass "PROMOTE_TO_APPROVED"
else
  fail "PROMOTE_TO_APPROVED" "promote to approved failed (rc=$rc, file_exists=$([ -f "$APPROVED_PLAN" ] && echo yes || echo no))"
fi

# --- CASE 6: Sign in-progress (plan now in approved/) ---
# The plan body is stable from initial commit onward — test results link already
# present in the initial content. Body hash must not change between any two signings
# (§D9.4 carry-forward). Architecture evidence touches only architecture/, not the plan.
printf '\nupdated by smoke test\n' >> "$REPO/architecture/key-scripts.md"
git -C "$REPO" add "$REPO/architecture/key-scripts.md"
git -C "$REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "chore: update arch doc"
rc=0
REPO="$REPO" bash "$SIGN" "$APPROVED_PLAN" in_progress 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "INPROGRESS_SIGN"; else fail "INPROGRESS_SIGN" "orianna-sign.sh in_progress exited $rc"; fi

# --- CASE 7: Promote to in-progress ---
rc=0
REPO="$REPO" NO_PUSH=1 bash "$PROMOTE" "$APPROVED_PLAN" in-progress 2>/dev/null || rc=$?
INPROGRESS_PLAN="$REPO/plans/in-progress/$SLUG.md"
if [ "$rc" -eq 0 ] && [ -f "$INPROGRESS_PLAN" ]; then
  pass "PROMOTE_TO_INPROGRESS"
else
  fail "PROMOTE_TO_INPROGRESS" "promote to in-progress failed (rc=$rc, file_exists=$([ -f "$INPROGRESS_PLAN" ] && echo yes || echo no))"
fi

# --- CASE 7: Sign implemented ---
# No plan body edits needed: the CI link was added before in_progress signing,
# so the body hash is stable. The implemented gate verifies the Test results
# section exists with a link (already present) and that carry-forward sigs match.
rc=0
REPO="$REPO" bash "$SIGN" "$INPROGRESS_PLAN" implemented 2>/dev/null || rc=$?
if [ "$rc" -eq 0 ]; then pass "IMPLEMENTED_SIGN"; else fail "IMPLEMENTED_SIGN" "orianna-sign.sh implemented exited $rc"; fi

# --- CASE 8: Promote to implemented ---
rc=0
REPO="$REPO" NO_PUSH=1 bash "$PROMOTE" "$INPROGRESS_PLAN" implemented 2>/dev/null || rc=$?
IMPLEMENTED_PLAN="$REPO/plans/implemented/$SLUG.md"
if [ "$rc" -eq 0 ] && [ -f "$IMPLEMENTED_PLAN" ]; then
  pass "PROMOTE_TO_IMPLEMENTED"
else
  fail "PROMOTE_TO_IMPLEMENTED" "promote to implemented failed (rc=$rc)"
fi

# --- CASE 9: Post-hoc verify all three signatures ---
ALL_VALID=1
for phase in approved in_progress implemented; do
  rc=0
  bash "$VERIFY" "$IMPLEMENTED_PLAN" "$phase" 2>/dev/null || rc=$?
  if [ "$rc" -ne 0 ]; then ALL_VALID=0; fi
done
if [ "$ALL_VALID" -eq 1 ]; then
  pass "POSTHOC_ALL_SIGS_VALID"
else
  fail "POSTHOC_ALL_SIGS_VALID" "one or more post-hoc signature verifications failed"
fi

rm -rf "$REPO"

# --- CASE 10 (T7.2): Offline-fail — claude CLI absent → sign exits non-zero with "signature unavailable" ---
HERMETIC_REPO="$(mktemp -d)"
git -C "$HERMETIC_REPO" init -q
git -C "$HERMETIC_REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit --allow-empty -q -m "init"
mkdir -p "$HERMETIC_REPO/plans/proposed"
HERMETIC_PLAN="$HERMETIC_REPO/plans/proposed/2026-04-20-hermetic-plan.md"
cat > "$HERMETIC_PLAN" << 'HPLANEOF'
---
title: Hermetic Plan
status: proposed
owner: test
created: 2026-04-20
tags: [test]
orianna_gate_version: 2
---

# Body

Content for offline-fail test.
HPLANEOF
git -C "$HERMETIC_REPO" add .
git -C "$HERMETIC_REPO" -c user.email="test@example.com" -c user.name="Tester" \
  commit -q -m "add hermetic plan"

# Run orianna-sign.sh with a PATH that has no claude binary
rc=0
stderr_out="$(PATH=/usr/bin:/bin REPO="$HERMETIC_REPO" bash "$SIGN" "$HERMETIC_PLAN" approved 2>&1)" || rc=$?

OFFLINE_OK=0
if [ "$rc" -ne 0 ]; then
  # Verify the stderr contains "signature unavailable" (per §D9.2)
  if printf '%s' "$stderr_out" | grep -qi "signature unavailable"; then
    OFFLINE_OK=1
  fi
fi

if [ "$OFFLINE_OK" -eq 1 ]; then
  pass "OFFLINE_FAIL_T7_2"
else
  fail "OFFLINE_FAIL_T7_2" "expected non-zero exit with 'signature unavailable', got rc=$rc, stderr=$stderr_out"
fi
rm -rf "$HERMETIC_REPO"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
