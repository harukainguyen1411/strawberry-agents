#!/usr/bin/env bats
# xfail: TT-INV — invariant regression suite.
#
# One named test per invariant from the §Test plan (8 invariants).
# Each test cites its invariant by name in a comment.
# Guards every named §Test plan invariant has at least one regression test
# (Rule 13 prophylaxis — these invariants are the regression surface).
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md
#       §Test plan (invariants list), TT-INV
# xfail: all tests are expected to fail until the relevant impl task lands.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/_lib_decision_capture.sh"
CAPTURE_SCRIPT="$REPO_ROOT/scripts/capture-decision.sh"
CONSOLIDATE_SCRIPT="$REPO_ROOT/scripts/memory-consolidate.sh"
EVELYNN_AGENT="$REPO_ROOT/.claude/agents/evelynn.md"
SONA_AGENT="$REPO_ROOT/.claude/agents/sona.md"
END_SESSION_SKILL="$REPO_ROOT/.claude/skills/end-session/SKILL.md"

setup() {
  export DECISION_TEST_MODE=1
  if [ -f "$LIB" ]; then
    # shellcheck source=/dev/null
    . "$LIB"
  fi
}

# ── Invariant: Schema ─────────────────────────────────────────────────────────

@test "TT-INV | guards Invariant: Schema — validate_decision_frontmatter enforces all required keys" {
  # guards Invariant: Schema
  # Every decision log file must carry valid frontmatter per §3.1.
  # Validator rejects missing required fields.
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  # Missing coordinator_confidence
  f="$TMPDIR_TEST/schema-test.md"
  cat > "$f" <<'YAML'
---
decision_id: 2026-04-25-schema-inv-test
date: 2026-04-25
session_short_uuid: inv00001
coordinator: evelynn
axes: [scope-vs-debt]
question: "Schema invariant test?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-inv00001
---
YAML
  run validate_decision_frontmatter "$f"
  [ "$status" -ne 0 ]
  rm -rf "$TMPDIR_TEST"
}

# ── Invariant: Rollup-idempotency ─────────────────────────────────────────────

@test "TT-INV | guards Invariant: Rollup-idempotency — two rollup runs produce byte-identical INDEX.md" {
  # guards Invariant: Rollup-idempotency
  # Running memory-consolidate.sh --decisions-only twice produces byte-identical
  # INDEX.md and byte-identical Samples:/Notable misses: lines in preferences.md.
  [ -f "$CONSOLIDATE_SCRIPT" ]
  grep -q "decisions-only" "$CONSOLIDATE_SCRIPT"

  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/agents/evelynn/memory/decisions/log"
  cat > "$TMPDIR_TEST/agents/evelynn/memory/decisions/log/2026-04-25-idem-test.md" <<'YAML'
---
decision_id: 2026-04-25-idem-test
date: 2026-04-25
session_short_uuid: inv00002
coordinator: evelynn
axes: [scope-vs-debt]
question: "Idempotency invariant test?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-inv00002
---
## Context
Idempotency test.
## Why this matters
Invariant regression.
YAML
  cat > "$TMPDIR_TEST/agents/evelynn/memory/decisions/axes.md" <<'EOF'
## scope-vs-debt
  Added: 2026-04-21
  Definition: Cleanness vs debt.
EOF
  cat > "$TMPDIR_TEST/agents/evelynn/memory/decisions/preferences.md" <<'EOF'
## Axis: scope-vs-debt
  Samples: 0 (a: 0, b: 0, c: 0) · Match rate: 0% · Confidence: low
  Summary: Test.
  Notable misses: none yet.
EOF
  export STRAWBERRY_MEMORY_ROOT="$TMPDIR_TEST"
  bash "$CONSOLIDATE_SCRIPT" evelynn --decisions-only >/dev/null
  INDEX="$TMPDIR_TEST/agents/evelynn/memory/decisions/INDEX.md"
  hash1="$(md5 -q "$INDEX" 2>/dev/null || md5sum "$INDEX" | cut -d' ' -f1)"
  bash "$CONSOLIDATE_SCRIPT" evelynn --decisions-only >/dev/null
  hash2="$(md5 -q "$INDEX" 2>/dev/null || md5sum "$INDEX" | cut -d' ' -f1)"
  [ "$hash1" = "$hash2" ]
  rm -rf "$TMPDIR_TEST"
}

# ── Invariant: Ordering ───────────────────────────────────────────────────────

@test "TT-INV | guards Invariant: Ordering — Step 6c in end-session SKILL.md appears before Step 9" {
  # guards Invariant: Ordering
  # /end-session Step 6c must run after Step 6b and before Step 9.
  # A synthetic SKILL.md with Step 6c BEFORE Step 6b must be detectable.
  [ -f "$END_SESSION_SKILL" ]
  grep -q "6c\|decisions-only" "$END_SESSION_SKILL"

  step_6c_line="$(grep -n "6c\|decisions-only" "$END_SESSION_SKILL" | head -1 | cut -d: -f1)"
  step_9_line="$(grep -n "^## Step 9\|^### Step 9\|Step 9 " "$END_SESSION_SKILL" | head -1 | cut -d: -f1)"
  [ -n "$step_6c_line" ]
  [ -n "$step_9_line" ]
  [ "$step_6c_line" -lt "$step_9_line" ]
}

# ── Invariant: Axis-introduction-gate ─────────────────────────────────────────

@test "TT-INV | guards Invariant: Axis-introduction-gate — undeclared axis causes rollup to fail loud" {
  # guards Invariant: Axis-introduction-gate
  # rollup script must fail with a [lib-decision] BLOCK: message when a log
  # tags an axis not present in axes.md.
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  cat > "$TMPDIR_TEST/decisions/log/2026-04-25-unknown-axis.md" <<'YAML'
---
decision_id: 2026-04-25-unknown-axis
date: 2026-04-25
session_short_uuid: inv00003
coordinator: evelynn
axes: [totally-unknown-axis]
question: "Axis gate invariant test?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-inv00003
---
YAML
  cat > "$TMPDIR_TEST/decisions/axes.md" <<'EOF'
## scope-vs-debt
  Added: 2026-04-21
  Definition: Cleanness vs debt.
EOF
  run regenerate_decisions_index "$TMPDIR_TEST" "$TMPDIR_TEST/decisions/INDEX.md" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"[lib-decision] BLOCK"* ]]
  rm -rf "$TMPDIR_TEST"
}

# ── Invariant: Hands-off-separation ───────────────────────────────────────────

@test "TT-INV | guards Invariant: Hands-off-separation — auto-decide picks counted separately" {
  # guards Invariant: Hands-off-separation
  # coordinator_autodecided: true decisions must appear in the +N hands-off
  # parenthetical and NOT inflate the explicit-pick denominator.
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  # One explicit match
  cat > "$TMPDIR_TEST/decisions/log/2026-04-25-explicit.md" <<'YAML'
---
decision_id: 2026-04-25-explicit
date: 2026-04-25
session_short_uuid: inv00004a
coordinator: evelynn
axes: [scope-vs-debt]
question: "Explicit?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-inv00004a
---
## Context
Explicit.
## Why this matters
Separation invariant.
YAML
  # One auto-decide
  cat > "$TMPDIR_TEST/decisions/log/2026-04-25-auto.md" <<'YAML'
---
decision_id: 2026-04-25-auto
date: 2026-04-25
session_short_uuid: inv00004b
coordinator: evelynn
axes: [scope-vs-debt]
question: "Auto?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Auto-decide."
duong_pick: hands-off-autodecide
duong_concurred_silently: false
coordinator_autodecided: true
match: true
decision_source: /end-session-shard-inv00004b
---
## Context
Auto-decide.
## Why this matters
Separation invariant.
YAML
  cat > "$TMPDIR_TEST/decisions/axes.md" <<'EOF'
## scope-vs-debt
  Added: 2026-04-21
  Definition: Cleanness vs debt.
EOF
  cat > "$TMPDIR_TEST/decisions/preferences.md" <<'EOF'
## Axis: scope-vs-debt
  Samples: 0 (a: 0, b: 0, c: 0) · Match rate: 0% · Confidence: low
  Summary: Test.
  Notable misses: none yet.
EOF
  run rollup_preferences_counts "$TMPDIR_TEST" "$TMPDIR_TEST/decisions/preferences.md"
  [ "$status" -eq 0 ]
  # Explicit sample count must be 1, not 2
  run grep "Samples: 1" "$TMPDIR_TEST/decisions/preferences.md"
  [ "$status" -eq 0 ]
  # +1 hands-off parenthetical must appear
  run grep "+1 hands-off" "$TMPDIR_TEST/decisions/preferences.md"
  [ "$status" -eq 0 ]
  rm -rf "$TMPDIR_TEST"
}

# ── Invariant: No-orphan ──────────────────────────────────────────────────────

@test "TT-INV | guards Invariant: No-orphan — capture-decision.sh refuses when log/ does not exist" {
  # guards Invariant: No-orphan
  # capture-decision.sh must exit non-zero with a [capture-decision] BLOCK:
  # message when decisions/log/ does not exist for the coordinator.
  [ -f "$CAPTURE_SCRIPT" ]
  TMPDIR_TEST="$(mktemp -d)"
  # Create coordinator dir WITHOUT decisions/log/
  mkdir -p "$TMPDIR_TEST/agents/evelynn/memory/decisions"
  # No log/ subdirectory
  LOG_FIXTURE="$(mktemp)"
  cat > "$LOG_FIXTURE" <<'YAML'
---
decision_id: 2026-04-25-orphan-test
date: 2026-04-25
session_short_uuid: inv00005
coordinator: evelynn
axes: [scope-vs-debt]
question: "Orphan test?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Test."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-inv00005
---
YAML
  export STRAWBERRY_MEMORY_ROOT="$TMPDIR_TEST"
  run bash "$CAPTURE_SCRIPT" evelynn --file "$LOG_FIXTURE" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"[capture-decision] BLOCK"* ]]
  rm -rf "$TMPDIR_TEST"
  rm -f "$LOG_FIXTURE"
}

# ── Invariant: Eager-boundary ─────────────────────────────────────────────────

@test "TT-INV | guards Invariant: Eager-boundary — evelynn.md does not eager-load decisions/log/" {
  # guards Invariant: Eager-boundary
  # decisions/INDEX.md and decisions/log/ must never appear in the boot chain.
  [ -f "$EVELYNN_AGENT" ]
  # preferences.md and axes.md must be present (positive assertion)
  grep -q "decisions/preferences.md" "$EVELYNN_AGENT"
  grep -q "decisions/axes.md" "$EVELYNN_AGENT"
  # log/ and INDEX.md must NOT be present (negative assertion)
  run grep "decisions/log/" "$EVELYNN_AGENT"
  [ "$status" -ne 0 ]
  run grep "decisions/INDEX\.md" "$EVELYNN_AGENT"
  [ "$status" -ne 0 ]
}

# ── Invariant: Capture-ritual-shape ──────────────────────────────────────────

@test "TT-INV | guards Invariant: Capture-ritual-shape — evelynn.md has Predict: and Confidence: in Decision Capture Protocol" {
  # guards Invariant: Capture-ritual-shape
  # The Decision Capture Protocol block in the coordinator agent def must carry
  # both Predict: and Confidence: lines with the three-bucket enum.
  [ -f "$EVELYNN_AGENT" ]
  grep -q "Predict:" "$EVELYNN_AGENT"
  grep -q "Confidence:" "$EVELYNN_AGENT"
  grep -q "low|medium|high" "$EVELYNN_AGENT"
  grep -q "decision-capture" "$EVELYNN_AGENT"
}
