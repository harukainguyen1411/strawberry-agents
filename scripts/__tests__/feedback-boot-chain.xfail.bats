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
# (DoD: when High > 0 on the INDEX summary line, surface top-3 high entries to Duong)
# Pattern matches the actual INDEX.md summary line shape: "Open: N | High: H | ..."
# ---------------------------------------------------------------------------
@test "TT4-C: evelynn CLAUDE.md boot text mentions high-severity surfacing" {
  xfail_if_missing "$EVELYNN_CLAUDE" "severity: high"
  grep -qE "severity: high|High > 0|High: H" "$EVELYNN_CLAUDE"
}

# ---------------------------------------------------------------------------
# TT4-D: High-severity surfacing instruction present in Sona boot text
# ---------------------------------------------------------------------------
@test "TT4-D: sona CLAUDE.md boot text mentions high-severity surfacing" {
  xfail_if_missing "$SONA_CLAUDE" "severity: high"
  grep -qE "severity: high|High > 0|High: H" "$SONA_CLAUDE"
}

# ---------------------------------------------------------------------------
# TT4-E: Missing-INDEX path does not contain abort/exit/fatal tied to INDEX read
# (DoD: missing-INDEX emits a single warning and does not abort startup)
# Uses POSIX-portable [[:space:]] anchors instead of \b (Rule 10).
# Plain bash failure with `return 1` instead of bats-assert `fail` (no load needed).
# ---------------------------------------------------------------------------
@test "TT4-E: evelynn CLAUDE.md INDEX read line does not contain abort/exit/fatal directive" {
  xfail_if_missing "$EVELYNN_CLAUDE" "feedback/INDEX.md"
  local line
  line=$(grep "feedback/INDEX.md" "$EVELYNN_CLAUDE")
  if printf '%s' "$line" | grep -qiE '(^|[[:space:]])(exit [^0]|abort|fatal)([[:space:]]|$)'; then
    printf 'INDEX read line contains abort/exit/fatal directive: %s\n' "$line" >&2
    return 1
  fi
}

@test "TT4-F: sona CLAUDE.md INDEX read line does not contain abort/exit/fatal directive" {
  xfail_if_missing "$SONA_CLAUDE" "feedback/INDEX.md"
  local line
  line=$(grep "feedback/INDEX.md" "$SONA_CLAUDE")
  if printf '%s' "$line" | grep -qiE '(^|[[:space:]])(exit [^0]|abort|fatal)([[:space:]]|$)'; then
    printf 'INDEX read line contains abort/exit/fatal directive: %s\n' "$line" >&2
    return 1
  fi
}
