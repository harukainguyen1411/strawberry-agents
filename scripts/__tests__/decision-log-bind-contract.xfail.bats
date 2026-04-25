#!/usr/bin/env bats
# xfail: TT1-bind — §3.5 dashboard read contract bind-point tests.
#
# Guards the four bind-points the retrospection dashboard reads from decision-log
# files: axes (YAML list), match (boolean), coordinator_confidence (enum), and
# decision_id (string matching filename stem).
#
# OQ-T1 resolution: DECISION_TEST_MODE=1 activates rename-hook env overrides
# in _lib_decision_capture.sh — tests use the production code path.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md
#       §3.5, TT1-bind
# xfail: all tests are expected to fail until T2 implements the validator.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/_lib_decision_capture.sh"
VALID_FIXTURE_DIR="$REPO_ROOT/scripts/__tests__/fixtures/decisions/valid"
MUTATED_FIXTURE_DIR="$REPO_ROOT/scripts/__tests__/fixtures/decisions/bind-mutation"

setup() {
  export DECISION_TEST_MODE=1
  if [ -f "$LIB" ]; then
    # shellcheck source=/dev/null
    . "$LIB"
  fi
}

# ── (a) Valid fixtures carry all four bind-points and pass validation ─────────

@test "TT1-bind: valid fixture carries axes as YAML list and passes validate_decision_frontmatter" {
  # xfail: requires _lib_decision_capture.sh (T2)
  [ -f "$LIB" ]
  for f in "$VALID_FIXTURE_DIR"/*.md; do
    run validate_decision_frontmatter "$f"
    [ "$status" -eq 0 ]
    # axes must be a YAML list (square-bracket notation)
    run grep -E "^axes: \[" "$f"
    [ "$status" -eq 0 ]
  done
}

@test "TT1-bind: valid fixture carries match as boolean (true or false)" {
  # xfail: requires fixture files to be present and validator to run
  for f in "$VALID_FIXTURE_DIR"/*.md; do
    run grep -E "^match: (true|false)$" "$f"
    [ "$status" -eq 0 ]
  done
}

@test "TT1-bind: valid fixture coordinator_confidence is one of low|medium|medium-high|high" {
  # xfail: §3.5 four-bucket display enum
  for f in "$VALID_FIXTURE_DIR"/*.md; do
    run grep -E "^coordinator_confidence: (low|medium|medium-high|high)$" "$f"
    [ "$status" -eq 0 ]
  done
}

@test "TT1-bind: valid fixture decision_id matches filename stem" {
  # xfail: decision_id == filename without .md extension
  for f in "$VALID_FIXTURE_DIR"/*.md; do
    stem="$(basename "$f" .md)"
    run grep -E "^decision_id: ${stem}$" "$f"
    [ "$status" -eq 0 ]
  done
}

# ── (b)-(c) Mutation simulations — rename of each bind-point trips assertion ──

@test "TT1-bind: DECISION_RENAME_AXES=topics causes axes bind-check to FAIL (rename tripwire)" {
  # xfail: requires DECISION_TEST_MODE=1 + rename-hook in _lib_decision_capture.sh
  [ -f "$LIB" ]
  export DECISION_RENAME_AXES=topics
  f="$MUTATED_FIXTURE_DIR/mutated-axes.md"
  [ -f "$f" ]
  # The mutated file has 'topics:' not 'axes:' — the bind check must detect this
  run validate_decision_frontmatter "$f"
  [ "$status" -ne 0 ]
  unset DECISION_RENAME_AXES
}

@test "TT1-bind: DECISION_RENAME_MATCH=matched causes match bind-check to FAIL" {
  # xfail: rename tripwire for match -> matched
  [ -f "$LIB" ]
  export DECISION_RENAME_MATCH=matched
  f="$MUTATED_FIXTURE_DIR/mutated-match.md"
  [ -f "$f" ]
  run validate_decision_frontmatter "$f"
  [ "$status" -ne 0 ]
  unset DECISION_RENAME_MATCH
}

@test "TT1-bind: DECISION_RENAME_COORD_CONF=coord_conf causes coordinator_confidence bind-check to FAIL" {
  # xfail: rename tripwire for coordinator_confidence -> coord_conf
  [ -f "$LIB" ]
  export DECISION_RENAME_COORD_CONF=coord_conf
  f="$MUTATED_FIXTURE_DIR/mutated-coordinator-confidence.md"
  [ -f "$f" ]
  run validate_decision_frontmatter "$f"
  [ "$status" -ne 0 ]
  unset DECISION_RENAME_COORD_CONF
}

@test "TT1-bind: DECISION_RENAME_DECISION_ID=log_id causes decision_id bind-check to FAIL" {
  # xfail: rename tripwire for decision_id -> log_id
  [ -f "$LIB" ]
  export DECISION_RENAME_DECISION_ID=log_id
  f="$MUTATED_FIXTURE_DIR/mutated-decision-id.md"
  [ -f "$f" ]
  run validate_decision_frontmatter "$f"
  [ "$status" -ne 0 ]
  unset DECISION_RENAME_DECISION_ID
}

# ── (d) coordinator_confidence: very-high rejected with stderr citing §3.5 enum ─

@test "TT1-bind: coordinator_confidence: very-high rejected with stderr citing the enum" {
  # xfail: requires _lib_decision_capture.sh (T2)
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  f="$TMPDIR_TEST/bad-conf.md"
  cat > "$f" <<'YAML'
---
decision_id: 2026-04-21-test-bad-conf
date: 2026-04-21
session_short_uuid: abcdef01
coordinator: evelynn
axes: [scope-vs-debt]
question: "Test?"
options:
  - letter: a
    description: "Option a"
coordinator_pick: a
coordinator_confidence: very-high
coordinator_rationale: "Test."
duong_pick: a
duong_concurred_silently: false
coordinator_autodecided: false
match: true
decision_source: /end-session-shard-abcdef01
---
YAML
  run validate_decision_frontmatter "$f"
  [ "$status" -ne 0 ]
  # stderr must mention "very-high" — confirms it's citing the bad value
  [[ "$output" == *"very-high"* ]] || [[ "$stderr" == *"very-high"* ]]
  rm -rf "$TMPDIR_TEST"
}

# ── (e) decision_id != filename stem is rejected ──────────────────────────────

@test "TT1-bind: decision_id not matching filename stem is rejected" {
  # xfail: requires _lib_decision_capture.sh (T2)
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  # File named 2026-04-21-correct-name.md but decision_id is 2026-04-21-wrong-name
  f="$TMPDIR_TEST/2026-04-21-correct-name.md"
  cat > "$f" <<'YAML'
---
decision_id: 2026-04-21-wrong-name
date: 2026-04-21
session_short_uuid: abcdef01
coordinator: evelynn
axes: [scope-vs-debt]
question: "Test?"
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
decision_source: /end-session-shard-abcdef01
---
YAML
  run validate_decision_frontmatter "$f"
  [ "$status" -ne 0 ]
  rm -rf "$TMPDIR_TEST"
}
