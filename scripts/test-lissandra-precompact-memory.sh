#!/bin/sh
# xfail: X4 — Lissandra pre-compact Step 6b symmetry tests
# Plan: plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
# Task: T5 (xfail) → gates T7 (Lissandra Step 6b parity with /end-session)
# Ref: test plan §2.7 assertions G1–G7
#
# Run: bash scripts/test-lissandra-precompact-memory.sh
#
# Grep-based shape check: verifies that .claude/agents/lissandra.md and
# agents/lissandra/profile.md contain Step-6b-equivalent protocol sections
# that are symmetric with /end-session's Step 6b.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LISSANDRA_AGENT="$REPO_ROOT/.claude/agents/lissandra.md"
LISSANDRA_PROFILE="$REPO_ROOT/agents/lissandra/profile.md"
PRECOMPACT_SKILL="$REPO_ROOT/.claude/skills/pre-compact-save/SKILL.md"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard: Lissandra Step 6b protocol section not yet implemented ---
# xfail: T7 (Lissandra Step 6b parity) not yet implemented
MISSING=""
if [ ! -f "$LISSANDRA_AGENT" ]; then
  MISSING="$MISSING .claude/agents/lissandra.md"
elif ! grep -q 'open-threads\|step.*6b\|Step 6b\|INDEX\.md.*regen\|memory-consolidate.*--index-only' "$LISSANDRA_AGENT" 2>/dev/null; then
  MISSING="$MISSING .claude/agents/lissandra.md:Step-6b-protocol"
fi

if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  for c in \
    G1_LISSANDRA_AGENT_HAS_STEP6B_PROTOCOL \
    G2_PARSES_OPEN_THREADS_SECTION \
    G3_WRITES_OPEN_THREADS_BOTH_COORDINATORS \
    G4_REGENERATES_INDEX_VIA_CONSOLIDATE \
    G5_STAGES_THREE_ARTIFACTS \
    G6_PRECOMPACT_SKILL_NOTE \
    G7_PROFILE_MIRRORS_AGENT_DEF
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 7 xfail (expected — T7 Lissandra Step 6b not yet implemented)\n'
  exit 0
fi

# --- G1: .claude/agents/lissandra.md includes a Step-6b-equivalent protocol section ---
if grep -qi 'step.*6b\|open-threads\|coordinator.*close.*protocol\|pre-compact.*protocol' "$LISSANDRA_AGENT" 2>/dev/null; then
  pass "G1_LISSANDRA_AGENT_HAS_STEP6B_PROTOCOL"
else
  fail "G1_LISSANDRA_AGENT_HAS_STEP6B_PROTOCOL" "no Step 6b protocol section found in $LISSANDRA_AGENT"
fi

# --- G2: Section parses shard's "## Open threads into next session" block ---
if grep -q 'Open threads into next session\|open-threads.*parse\|parse.*open-threads\|## Open threads' "$LISSANDRA_AGENT" 2>/dev/null; then
  pass "G2_PARSES_OPEN_THREADS_SECTION"
else
  fail "G2_PARSES_OPEN_THREADS_SECTION" "no reference to parsing '## Open threads into next session' in $LISSANDRA_AGENT"
fi

# --- G3: Writes into open-threads.md for BOTH evelynn AND sona ---
has_evelynn=0
has_sona=0
grep -q 'evelynn' "$LISSANDRA_AGENT" 2>/dev/null && has_evelynn=1
grep -q 'sona' "$LISSANDRA_AGENT" 2>/dev/null && has_sona=1
if [ "$has_evelynn" -eq 1 ] && [ "$has_sona" -eq 1 ]; then
  pass "G3_WRITES_OPEN_THREADS_BOTH_COORDINATORS"
else
  fail "G3_WRITES_OPEN_THREADS_BOTH_COORDINATORS" "evelynn or sona not mentioned in Lissandra protocol (evelynn=$has_evelynn sona=$has_sona)"
fi

# --- G4: Regenerates INDEX via memory-consolidate.sh --index-only ---
if grep -q 'memory-consolidate.*--index-only\|--index-only.*memory-consolidate\|scripts/memory-consolidate\.sh' "$LISSANDRA_AGENT" 2>/dev/null; then
  pass "G4_REGENERATES_INDEX_VIA_CONSOLIDATE"
else
  fail "G4_REGENERATES_INDEX_VIA_CONSOLIDATE" "memory-consolidate.sh --index-only not referenced in $LISSANDRA_AGENT"
fi

# --- G5: Stages all three artifacts (shard + open-threads + INDEX) before commit ---
has_shard_stage=0
has_openthreads_stage=0
has_index_stage=0
grep -q 'git add.*last-sessions\|git add.*shard\|stage.*shard' "$LISSANDRA_AGENT" 2>/dev/null && has_shard_stage=1
grep -q 'git add.*open-threads\|stage.*open-threads' "$LISSANDRA_AGENT" 2>/dev/null && has_openthreads_stage=1
grep -q 'git add.*INDEX\|stage.*INDEX' "$LISSANDRA_AGENT" 2>/dev/null && has_index_stage=1
if [ "$has_shard_stage" -eq 1 ] && [ "$has_openthreads_stage" -eq 1 ] && [ "$has_index_stage" -eq 1 ]; then
  pass "G5_STAGES_THREE_ARTIFACTS"
else
  fail "G5_STAGES_THREE_ARTIFACTS" "missing stage instructions: shard=$has_shard_stage open-threads=$has_openthreads_stage INDEX=$has_index_stage"
fi

# --- G6: pre-compact-save/SKILL.md carries a one-line note about Lissandra + open-threads + INDEX ---
if [ -f "$PRECOMPACT_SKILL" ] && \
   grep -qi 'open-threads\|INDEX\.md\|lissandra.*index\|lissandra.*open-threads' "$PRECOMPACT_SKILL" 2>/dev/null; then
  pass "G6_PRECOMPACT_SKILL_NOTE"
else
  fail "G6_PRECOMPACT_SKILL_NOTE" "pre-compact-save SKILL.md missing Lissandra+open-threads+INDEX note"
fi

# --- G7: agents/lissandra/profile.md mirrors G1–G5 (secondary source of truth) ---
if [ ! -f "$LISSANDRA_PROFILE" ]; then
  fail "G7_PROFILE_MIRRORS_AGENT_DEF" "agents/lissandra/profile.md does not exist"
else
  profile_ok=1
  # Profile must also reference the Step 6b protocol
  grep -qi 'open-threads\|step.*6b\|memory-consolidate.*--index-only\|INDEX\.md.*regen' "$LISSANDRA_PROFILE" 2>/dev/null || profile_ok=0
  # Profile must mention both coordinators
  grep -q 'evelynn' "$LISSANDRA_PROFILE" 2>/dev/null || profile_ok=0
  grep -q 'sona' "$LISSANDRA_PROFILE" 2>/dev/null || profile_ok=0
  if [ "$profile_ok" -eq 1 ]; then
    pass "G7_PROFILE_MIRRORS_AGENT_DEF"
  else
    fail "G7_PROFILE_MIRRORS_AGENT_DEF" "profile.md does not mirror lissandra.md Step 6b protocol"
  fi
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
