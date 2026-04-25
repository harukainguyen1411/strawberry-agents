#!/usr/bin/env bats
# xfail: TT5-protocol — capture-ritual shape invariant + Operating Modes addendum.
#
# Asserts that evelynn.md and sona.md Decision Capture Protocol sections carry
# the correct shape: Predict:, Confidence:, three-bucket enum, skill reference,
# retry-once-then-proceed rule, and Operating Modes hands-off addendum.
#
# Note: The prediction-confidence enum is three buckets (low|medium|high) per §6.2.
# The display enum is four buckets (low|medium|medium-high|high) per §3.5.
# These must NOT be collapsed — TT5-protocol tests the prediction enum;
# TT1-bind tests the display enum independently.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md
#       §6.2, §6.3, Failure mode #5, TT5-protocol
# xfail: all tests are expected to fail until T9 lands.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
EVELYNN_AGENT="$REPO_ROOT/.claude/agents/evelynn.md"
SONA_AGENT="$REPO_ROOT/.claude/agents/sona.md"

# ── evelynn.md Decision Capture Protocol ─────────────────────────────────────

@test "TT5-protocol: evelynn.md Decision Capture Protocol section contains Predict: line" {
  # xfail: requires T9 (§6.2 protocol)
  [ -f "$EVELYNN_AGENT" ]
  grep -q "Predict:" "$EVELYNN_AGENT"
}

@test "TT5-protocol: evelynn.md Decision Capture Protocol section contains Confidence: line" {
  # xfail: requires T9
  [ -f "$EVELYNN_AGENT" ]
  grep -q "Confidence:" "$EVELYNN_AGENT"
}

@test "TT5-protocol: evelynn.md Decision Capture Protocol Confidence: uses three-bucket prediction enum" {
  # xfail: prediction enum is low|medium|high (THREE buckets, per §6.2)
  # The display enum (§3.5) has four buckets — these must remain separate
  [ -f "$EVELYNN_AGENT" ]
  grep -q "low|medium|high" "$EVELYNN_AGENT"
}

@test "TT5-protocol: evelynn.md Decision Capture Protocol references the decision-capture skill" {
  # xfail: §6.2 step 2 — coordinator invokes the decision-capture skill
  [ -f "$EVELYNN_AGENT" ]
  grep -q "decision-capture" "$EVELYNN_AGENT"
}

@test "TT5-protocol: evelynn.md Decision Capture Protocol specifies retry-once-then-proceed" {
  # xfail: §6.2 step 3 + Failure mode #5 — guards non-blocking behaviour
  [ -f "$EVELYNN_AGENT" ]
  grep -q "retry once\|retry-once\|retry 1\|second failure" "$EVELYNN_AGENT"
}

@test "TT5-protocol: evelynn.md Operating Modes addendum mentions coordinator_autodecided: true" {
  # xfail: §6.3 hands-off mode addendum
  [ -f "$EVELYNN_AGENT" ]
  grep -q "coordinator_autodecided: true" "$EVELYNN_AGENT"
}

@test "TT5-protocol: evelynn.md Operating Modes addendum mentions hands-off autodecides counted separately" {
  # xfail: §6.3 — honesty mechanism for match-rate
  [ -f "$EVELYNN_AGENT" ]
  grep -qi "hands-off.*counted separately\|separately.*hands-off" "$EVELYNN_AGENT"
}

# ── sona.md — same five assertions ───────────────────────────────────────────

@test "TT5-protocol: sona.md Decision Capture Protocol section contains Predict: line" {
  # xfail: requires T9
  [ -f "$SONA_AGENT" ]
  grep -q "Predict:" "$SONA_AGENT"
}

@test "TT5-protocol: sona.md Decision Capture Protocol section contains Confidence: line" {
  # xfail: requires T9
  [ -f "$SONA_AGENT" ]
  grep -q "Confidence:" "$SONA_AGENT"
}

@test "TT5-protocol: sona.md Decision Capture Protocol Confidence: uses three-bucket prediction enum" {
  # xfail: §6.2 three-bucket prediction enum (low|medium|high)
  [ -f "$SONA_AGENT" ]
  grep -q "low|medium|high" "$SONA_AGENT"
}

@test "TT5-protocol: sona.md Decision Capture Protocol references the decision-capture skill" {
  # xfail: §6.2 step 2
  [ -f "$SONA_AGENT" ]
  grep -q "decision-capture" "$SONA_AGENT"
}

@test "TT5-protocol: sona.md Operating Modes addendum mentions coordinator_autodecided: true" {
  # xfail: §6.3 hands-off mode addendum
  [ -f "$SONA_AGENT" ]
  grep -q "coordinator_autodecided: true" "$SONA_AGENT"
}
