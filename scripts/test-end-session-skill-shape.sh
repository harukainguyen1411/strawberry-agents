#!/bin/sh
# xfail: X3 (part 1) — /end-session Step 6b skill shape tests
# Plan: plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
# Task: T5 (xfail) → gates T6 (end-session SKILL.md Step 6b injection)
# Ref: test plan §2.6 assertions F1–F7
#
# Run: bash scripts/test-end-session-skill-shape.sh
#
# Grep-based shape check: verifies that .claude/skills/end-session/SKILL.md
# contains a properly-formed Step 6b section with all required elements.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL="$REPO_ROOT/.claude/skills/end-session/SKILL.md"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard: Step 6b not yet injected into end-session skill ---
# xfail: Step 6b open-threads + INDEX regen not yet present in SKILL.md
MISSING=""
if [ ! -f "$SKILL" ]; then
  MISSING="$MISSING .claude/skills/end-session/SKILL.md"
elif ! grep -q 'Step 6b\|step 6b\|6b\.' "$SKILL" 2>/dev/null; then
  MISSING="$MISSING .claude/skills/end-session/SKILL.md:Step-6b"
fi

if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  for c in \
    F1_STEP_6B_HEADING \
    F2_REFERENCES_OPEN_THREADS \
    F3_REFERENCES_INDEX_REGEN \
    F4_ORDERING_6_BEFORE_6B_BEFORE_9 \
    F5_NOOP_FOR_NON_COORDINATOR \
    F6_EXACT_MEMORY_CONSOLIDATE_COMMAND \
    F7_GIT_ADD_LINES
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 7 xfail (expected — T6 Step 6b injection not yet implemented)\n'
  exit 0
fi

# --- F1: SKILL.md contains a "Step 6b" heading ---
if grep -q 'Step 6b\|step 6b' "$SKILL" 2>/dev/null; then
  pass "F1_STEP_6B_HEADING"
else
  fail "F1_STEP_6B_HEADING" "no 'Step 6b' heading found in $SKILL"
fi

# --- F2: Step 6b body references open-threads.md ---
if grep -q 'open-threads\.md' "$SKILL" 2>/dev/null; then
  pass "F2_REFERENCES_OPEN_THREADS"
else
  fail "F2_REFERENCES_OPEN_THREADS" "open-threads.md not referenced in $SKILL"
fi

# --- F3: Step 6b body references INDEX.md regeneration ---
if grep -q 'INDEX\.md\|index-only\|--index-only' "$SKILL" 2>/dev/null; then
  pass "F3_REFERENCES_INDEX_REGEN"
else
  fail "F3_REFERENCES_INDEX_REGEN" "INDEX.md regen not referenced in $SKILL"
fi

# --- F4: Ordering documented — Step 6 before 6b, 6b before Step 9 ---
# Check that the file documents the ordering invariant
if grep -qi 'step 6.*before.*6b\|6b.*before.*step 9\|6b.*before.*9\|ordering\|order.*6.*6b\|must complete before' "$SKILL" 2>/dev/null; then
  pass "F4_ORDERING_6_BEFORE_6B_BEFORE_9"
else
  fail "F4_ORDERING_6_BEFORE_6B_BEFORE_9" "ordering invariant (Step 6 → 6b → Step 9) not documented in $SKILL"
fi

# --- F5: Step 6b marked as no-op for non-coordinator agents ---
if grep -qi 'non-coordinator\|evelynn\|sona\|no-op\|skip.*non\|only.*coordinator' "$SKILL" 2>/dev/null; then
  pass "F5_NOOP_FOR_NON_COORDINATOR"
else
  fail "F5_NOOP_FOR_NON_COORDINATOR" "no-op clause for non-coordinator agents not found in $SKILL"
fi

# --- F6: Exact command "scripts/memory-consolidate.sh --index-only <coordinator>" appears ---
if grep -q 'scripts/memory-consolidate\.sh.*--index-only\|memory-consolidate\.sh.*--index-only' "$SKILL" 2>/dev/null; then
  pass "F6_EXACT_MEMORY_CONSOLIDATE_COMMAND"
else
  fail "F6_EXACT_MEMORY_CONSOLIDATE_COMMAND" "exact memory-consolidate.sh --index-only command not in $SKILL"
fi

# --- F7: git add lines for open-threads.md and INDEX.md appear ---
has_openthreads_add=0
has_index_add=0
grep -q 'git add.*open-threads\.md\|git add.*agents/.*open-threads' "$SKILL" 2>/dev/null && has_openthreads_add=1
grep -q 'git add.*INDEX\.md\|git add.*last-sessions/INDEX' "$SKILL" 2>/dev/null && has_index_add=1
if [ "$has_openthreads_add" -eq 1 ] && [ "$has_index_add" -eq 1 ]; then
  pass "F7_GIT_ADD_LINES"
else
  fail "F7_GIT_ADD_LINES" "git add lines missing: open-threads=$has_openthreads_add INDEX=$has_index_add"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
