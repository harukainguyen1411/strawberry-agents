#!/bin/sh
# xfail: X5 — boot-chain load order tests
# Plan: plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
# Task: T5 (xfail) → gates T9 (agent-def rewrite: Evelynn + Sona boot scripts)
# Ref: test plan §2.4 assertions D1–D7
#
# Run: bash scripts/test-boot-chain-order.sh
#
# Grep-based shape check: verifies that .claude/agents/evelynn.md and
# .claude/agents/sona.md have been rewritten with the ADR §7 boot order
# (8-file sequence with open-threads.md at position 7, INDEX.md at position 8),
# and that filter-last-sessions.sh has been removed from all boot prompts.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVELYNN_AGENT="$REPO_ROOT/.claude/agents/evelynn.md"
SONA_AGENT="$REPO_ROOT/.claude/agents/sona.md"
EVELYNN_CLAUDE="$REPO_ROOT/agents/evelynn/CLAUDE.md"
SONA_CLAUDE="$REPO_ROOT/agents/sona/CLAUDE.md"
AGENT_NETWORK="$REPO_ROOT/agents/memory/agent-network.md"
FILTER_SCRIPT="$REPO_ROOT/scripts/filter-last-sessions.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard: boot scripts not yet rewritten per ADR §7 ---
# xfail: T9 (boot script rewrite + filter-last-sessions.sh deletion) not yet implemented
# The new boot order has exactly 8 numbered items with open-threads.md + INDEX.md as tail.
MISSING=""
if [ ! -f "$EVELYNN_AGENT" ]; then
  MISSING="$MISSING .claude/agents/evelynn.md"
elif ! grep -q 'open-threads\.md' "$EVELYNN_AGENT" 2>/dev/null; then
  MISSING="$MISSING .claude/agents/evelynn.md:open-threads-boot-entry"
fi

if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  for c in \
    D1_EVELYNN_BOOT_ORDER_MATCHES_ADR_TABLE \
    D2_OPEN_THREADS_POS7_INDEX_POS8 \
    D3_NO_FILTER_LAST_SESSIONS_IN_PROMPT \
    D4_SONA_SYMMETRIC_TO_EVELYNN \
    D5_EVELYNN_CLAUDE_MD_MATCHES_BOOT_PROMPT \
    D6_SONA_CLAUDE_MD_HAS_STARTUP_SEQUENCE \
    D7_AGENT_NETWORK_HAS_MEMORY_CONSUMPTION_SECTION
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 7 xfail (expected — T9 boot script rewrite not yet implemented)\n'
  exit 0
fi

# --- D1: .claude/agents/evelynn.md initialPrompt reads files in ADR §7 order ---
# ADR §7 table (8-file sequence):
#   1. agents/evelynn/CLAUDE.md
#   2. agents/evelynn/profile.md
#   3. agents/evelynn/memory/evelynn.md
#   4. agents/memory/duong.md
#   5. agents/memory/agent-network.md
#   6. agents/evelynn/learnings/index.md
#   7. agents/evelynn/memory/open-threads.md
#   8. agents/evelynn/memory/last-sessions/INDEX.md
expected_files="
agents/evelynn/CLAUDE.md
agents/evelynn/profile.md
agents/evelynn/memory/evelynn.md
agents/memory/duong.md
agents/memory/agent-network.md
agents/evelynn/learnings/index.md
agents/evelynn/memory/open-threads.md
agents/evelynn/memory/last-sessions/INDEX.md
"
all_present=1
for f in $expected_files; do
  [ -z "$f" ] && continue
  grep -qF "$f" "$EVELYNN_AGENT" 2>/dev/null || { all_present=0; break; }
done
if [ "$all_present" -eq 1 ]; then
  pass "D1_EVELYNN_BOOT_ORDER_MATCHES_ADR_TABLE"
else
  fail "D1_EVELYNN_BOOT_ORDER_MATCHES_ADR_TABLE" "one or more ADR §7 files not in evelynn.md initialPrompt"
fi

# --- D2: open-threads.md is position 7, INDEX.md is position 8 (last two) ---
# Extract numbered list entries from initialPrompt (lines like "7. ..." or "  7. ...")
# Use grep -E on whole lines (POSIX-portable; avoids BSD grep -oE [^\n]+ bug on macOS).
PROMPT_LINES="$(grep -E '^\s*[0-9]+\.' "$EVELYNN_AGENT" 2>/dev/null || echo '')"
pos7_has_openthreads=0
pos8_has_index=0
printf '%s\n' "$PROMPT_LINES" | grep -q '^7\. .*open-threads\|^  7\. .*open-threads\|7\..*open-threads' && pos7_has_openthreads=1
printf '%s\n' "$PROMPT_LINES" | grep -q '^8\. .*INDEX\|^  8\. .*INDEX\|8\..*INDEX' && pos8_has_index=1
if [ "$pos7_has_openthreads" -eq 1 ] && [ "$pos8_has_index" -eq 1 ]; then
  pass "D2_OPEN_THREADS_POS7_INDEX_POS8"
else
  fail "D2_OPEN_THREADS_POS7_INDEX_POS8" "open-threads not at pos7 or INDEX not at pos8 (pos7=$pos7_has_openthreads pos8=$pos8_has_index)"
fi

# --- D3: No mention of filter-last-sessions.sh anywhere in the boot prompt ---
if grep -q 'filter-last-sessions' "$EVELYNN_AGENT" 2>/dev/null; then
  fail "D3_NO_FILTER_LAST_SESSIONS_IN_PROMPT" "filter-last-sessions.sh still referenced in evelynn.md"
else
  pass "D3_NO_FILTER_LAST_SESSIONS_IN_PROMPT"
fi

# Also check sona.md for the same
if grep -q 'filter-last-sessions' "$SONA_AGENT" 2>/dev/null; then
  fail "D3_NO_FILTER_LAST_SESSIONS_IN_PROMPT" "filter-last-sessions.sh still referenced in sona.md"
fi

# Also check filter script is deleted
if [ -f "$FILTER_SCRIPT" ]; then
  fail "D3_NO_FILTER_LAST_SESSIONS_IN_PROMPT" "filter-last-sessions.sh file still exists on disk"
fi

# --- D4: .claude/agents/sona.md symmetric to Evelynn (names swapped) ---
sona_files="
agents/sona/CLAUDE.md
agents/sona/profile.md
agents/sona/memory/sona.md
agents/memory/duong.md
agents/memory/agent-network.md
agents/sona/learnings/index.md
agents/sona/memory/open-threads.md
agents/sona/memory/last-sessions/INDEX.md
"
all_present_sona=1
for f in $sona_files; do
  [ -z "$f" ] && continue
  grep -qF "$f" "$SONA_AGENT" 2>/dev/null || { all_present_sona=0; break; }
done
# Also verify no filter-last-sessions reference in sona
has_filter_sona=0
grep -q 'filter-last-sessions' "$SONA_AGENT" 2>/dev/null && has_filter_sona=1
if [ "$all_present_sona" -eq 1 ] && [ "$has_filter_sona" -eq 0 ]; then
  pass "D4_SONA_SYMMETRIC_TO_EVELYNN"
else
  fail "D4_SONA_SYMMETRIC_TO_EVELYNN" "sona.md not symmetric to evelynn.md (files=$all_present_sona filter_ref=$has_filter_sona)"
fi

# --- D5: agents/evelynn/CLAUDE.md Startup Sequence matches boot prompt file order ---
if [ -f "$EVELYNN_CLAUDE" ]; then
  claude_has_openthreads=0
  claude_has_index=0
  grep -q 'open-threads' "$EVELYNN_CLAUDE" 2>/dev/null && claude_has_openthreads=1
  grep -q 'INDEX\.md\|last-sessions/INDEX' "$EVELYNN_CLAUDE" 2>/dev/null && claude_has_index=1
  if [ "$claude_has_openthreads" -eq 1 ] && [ "$claude_has_index" -eq 1 ]; then
    pass "D5_EVELYNN_CLAUDE_MD_MATCHES_BOOT_PROMPT"
  else
    fail "D5_EVELYNN_CLAUDE_MD_MATCHES_BOOT_PROMPT" "evelynn/CLAUDE.md Startup Sequence missing open-threads ($claude_has_openthreads) or INDEX ($claude_has_index)"
  fi
else
  fail "D5_EVELYNN_CLAUDE_MD_MATCHES_BOOT_PROMPT" "agents/evelynn/CLAUDE.md not found"
fi

# --- D6: agents/sona/CLAUDE.md has a "## Startup Sequence" section ---
if [ -f "$SONA_CLAUDE" ] && grep -q '## Startup Sequence\|## Startup sequence' "$SONA_CLAUDE" 2>/dev/null; then
  pass "D6_SONA_CLAUDE_MD_HAS_STARTUP_SEQUENCE"
else
  fail "D6_SONA_CLAUDE_MD_HAS_STARTUP_SEQUENCE" "agents/sona/CLAUDE.md missing ## Startup Sequence section"
fi

# --- D7: agents/memory/agent-network.md has "## Memory Consumption" section ---
if [ -f "$AGENT_NETWORK" ] && \
   grep -q '## Memory Consumption\|## Memory consumption' "$AGENT_NETWORK" 2>/dev/null && \
   grep -q 'open-threads\.md' "$AGENT_NETWORK" 2>/dev/null && \
   grep -q 'INDEX\.md\|last-sessions/INDEX' "$AGENT_NETWORK" 2>/dev/null && \
   grep -qi 'skarner' "$AGENT_NETWORK" 2>/dev/null; then
  pass "D7_AGENT_NETWORK_HAS_MEMORY_CONSUMPTION_SECTION"
else
  fail "D7_AGENT_NETWORK_HAS_MEMORY_CONSUMPTION_SECTION" "agent-network.md missing ## Memory Consumption + open-threads + INDEX + Skarner"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
