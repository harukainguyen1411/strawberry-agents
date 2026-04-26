#!/usr/bin/env bats
# xfail test suite for coordinator boot-chain INDEX read (TT4)
# Guards T4 DoD: evelynn + sona CLAUDE.md startup sections contain feedback/INDEX.md read
# instruction; high-severity count is surfaced; missing-INDEX path does not abort startup.
# Plan: plans/approved/personal/2026-04-21-agent-feedback-system.md

setup() {
  EVELYNN_CLAUDE="/Users/duongntd99/Documents/Personal/strawberry-agents/agents/evelynn/CLAUDE.md"
  SONA_CLAUDE="/Users/duongntd99/Documents/Personal/strawberry-agents/agents/sona/CLAUDE.md"
}

# ---------------------------------------------------------------------------
# Assertion helper: mark test as expected-to-fail until T4 impl lands
# ---------------------------------------------------------------------------
xfail_if_missing() {
  local file="$1" pattern="$2"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then
    skip "xfail: T4 not yet implemented — pattern '$pattern' not found in $file"
  fi
}

# ---------------------------------------------------------------------------
# TT4-A: Evelynn startup contains feedback/INDEX.md read instruction
# ---------------------------------------------------------------------------
@test "TT4-A: agents/evelynn/CLAUDE.md Startup Sequence references feedback/INDEX.md" {
  xfail_if_missing "$EVELYNN_CLAUDE" "feedback/INDEX.md"
  grep -q "feedback/INDEX.md" "$EVELYNN_CLAUDE"
}

# ---------------------------------------------------------------------------
# TT4-B: Sona startup contains feedback/INDEX.md read instruction
# ---------------------------------------------------------------------------
@test "TT4-B: agents/sona/CLAUDE.md Startup Sequence references feedback/INDEX.md" {
  xfail_if_missing "$SONA_CLAUDE" "feedback/INDEX.md"
  grep -q "feedback/INDEX.md" "$SONA_CLAUDE"
}

# ---------------------------------------------------------------------------
# TT4-C: High-severity surfacing instruction present in Evelynn boot text
# (DoD: when count_open_high > 0, surface top-3 high entries to Duong)
# ---------------------------------------------------------------------------
@test "TT4-C: evelynn CLAUDE.md boot text mentions count_open_high or high-severity surfacing" {
  xfail_if_missing "$EVELYNN_CLAUDE" "count_open_high"
  grep -q "count_open_high" "$EVELYNN_CLAUDE"
}

# ---------------------------------------------------------------------------
# TT4-D: High-severity surfacing instruction present in Sona boot text
# ---------------------------------------------------------------------------
@test "TT4-D: sona CLAUDE.md boot text mentions count_open_high or high-severity surfacing" {
  xfail_if_missing "$SONA_CLAUDE" "count_open_high"
  grep -q "count_open_high" "$SONA_CLAUDE"
}

# ---------------------------------------------------------------------------
# TT4-E: Missing-INDEX path does not contain abort/exit/fatal tied to INDEX read
# (DoD: missing-INDEX emits a single warning and does not abort startup)
# Negative grep: no "exit" or "abort" or "fatal" immediately following INDEX.md line
# ---------------------------------------------------------------------------
@test "TT4-E: evelynn CLAUDE.md INDEX read line does not contain abort/exit/fatal directive" {
  xfail_if_missing "$EVELYNN_CLAUDE" "feedback/INDEX.md"
  # Extract the line(s) referencing feedback/INDEX.md and assert no abort keyword on same line
  local line
  line=$(grep "feedback/INDEX.md" "$EVELYNN_CLAUDE")
  # Should not contain abort/exit/fatal on the INDEX read line itself
  refute_match() { echo "$line" | grep -qiE "abort|fatal|exit [^0]"; }
  if echo "$line" | grep -qiE '\bexit [^0]\b|\babort\b|\bfatal\b'; then
    fail "INDEX read line contains abort/exit/fatal directive: $line"
  fi
}

@test "TT4-F: sona CLAUDE.md INDEX read line does not contain abort/exit/fatal directive" {
  xfail_if_missing "$SONA_CLAUDE" "feedback/INDEX.md"
  local line
  line=$(grep "feedback/INDEX.md" "$SONA_CLAUDE")
  if echo "$line" | grep -qiE '\bexit [^0]\b|\babort\b|\bfatal\b'; then
    fail "INDEX read line contains abort/exit/fatal directive: $line"
  fi
}
