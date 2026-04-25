#!/usr/bin/env bats
# xfail: TT5-eager — eager-boundary invariant.
#
# Asserts that agent-def boot chains for evelynn and sona include
# preferences.md and axes.md at positions 8 and 9 (§6.1) and do NOT
# reference decisions/INDEX.md or decisions/log/ (lazy-load boundary §7.4).
#
# Also asserts the same split in agents/evelynn/CLAUDE.md and
# agents/sona/CLAUDE.md Startup Sequence sections (§6.4).
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md
#       §6.1, §6.4, §7.4, TT5-eager
# xfail: all tests are expected to fail until T9 + T10 land.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
EVELYNN_AGENT="$REPO_ROOT/.claude/agents/evelynn.md"
SONA_AGENT="$REPO_ROOT/.claude/agents/sona.md"
EVELYNN_CLAUDE="$REPO_ROOT/agents/evelynn/CLAUDE.md"
SONA_CLAUDE="$REPO_ROOT/agents/sona/CLAUDE.md"

# ── evelynn.md agent def — positions 8 and 9 present ────────────────────────

@test "TT5-eager: evelynn.md initialPrompt references decisions/preferences.md" {
  # xfail: requires T9 to add §6.1 boot entries
  [ -f "$EVELYNN_AGENT" ]
  grep -q "decisions/preferences.md" "$EVELYNN_AGENT"
}

@test "TT5-eager: evelynn.md initialPrompt references decisions/axes.md" {
  # xfail: requires T9
  [ -f "$EVELYNN_AGENT" ]
  grep -q "decisions/axes.md" "$EVELYNN_AGENT"
}

@test "TT5-eager: evelynn.md initialPrompt does NOT reference decisions/INDEX.md" {
  # xfail: lazy surfaces must not appear in the boot chain (§7.4)
  [ -f "$EVELYNN_AGENT" ]
  run grep "decisions/INDEX\.md" "$EVELYNN_AGENT"
  [ "$status" -ne 0 ]
}

@test "TT5-eager: evelynn.md initialPrompt does NOT reference decisions/log/" {
  # xfail: corpus is never eager-loaded (§7.4)
  [ -f "$EVELYNN_AGENT" ]
  run grep "decisions/log/" "$EVELYNN_AGENT"
  [ "$status" -ne 0 ]
}

# ── sona.md agent def — same checks ──────────────────────────────────────────

@test "TT5-eager: sona.md initialPrompt references decisions/preferences.md" {
  # xfail: requires T9
  [ -f "$SONA_AGENT" ]
  grep -q "decisions/preferences.md" "$SONA_AGENT"
}

@test "TT5-eager: sona.md initialPrompt references decisions/axes.md" {
  # xfail: requires T9
  [ -f "$SONA_AGENT" ]
  grep -q "decisions/axes.md" "$SONA_AGENT"
}

@test "TT5-eager: sona.md initialPrompt does NOT reference decisions/INDEX.md" {
  # xfail: lazy-load boundary (§7.4)
  [ -f "$SONA_AGENT" ]
  run grep "decisions/INDEX\.md" "$SONA_AGENT"
  [ "$status" -ne 0 ]
}

@test "TT5-eager: sona.md initialPrompt does NOT reference decisions/log/" {
  # xfail: lazy-load boundary (§7.4)
  [ -f "$SONA_AGENT" ]
  run grep "decisions/log/" "$SONA_AGENT"
  [ "$status" -ne 0 ]
}

# ── agents/evelynn/CLAUDE.md Startup Sequence (§6.4) ─────────────────────────

@test "TT5-eager: agents/evelynn/CLAUDE.md Startup Sequence lists decisions/preferences.md" {
  # xfail: requires T10
  [ -f "$EVELYNN_CLAUDE" ]
  grep -q "decisions/preferences.md" "$EVELYNN_CLAUDE"
}

@test "TT5-eager: agents/evelynn/CLAUDE.md Startup Sequence lists decisions/axes.md" {
  # xfail: requires T10
  [ -f "$EVELYNN_CLAUDE" ]
  grep -q "decisions/axes.md" "$EVELYNN_CLAUDE"
}

# ── agents/sona/CLAUDE.md Startup Sequence (§6.4) ────────────────────────────

@test "TT5-eager: agents/sona/CLAUDE.md Startup Sequence lists decisions/preferences.md" {
  # xfail: requires T10
  [ -f "$SONA_CLAUDE" ]
  grep -q "decisions/preferences.md" "$SONA_CLAUDE"
}

@test "TT5-eager: agents/sona/CLAUDE.md Startup Sequence lists decisions/axes.md" {
  # xfail: requires T10
  [ -f "$SONA_CLAUDE" ]
  grep -q "decisions/axes.md" "$SONA_CLAUDE"
}
