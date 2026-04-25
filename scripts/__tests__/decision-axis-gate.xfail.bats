#!/usr/bin/env bats
# xfail: TT4-axisgate — axis-introduction gate invariant.
#
# Verifies that the rollup script refuses to process decision logs tagging
# axes not declared in axes.md, and handles deprecated axes correctly.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md
#       §3.4, §4.3, TT4-axisgate
# xfail: all tests are expected to fail until T4 implements the axis-gate logic.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/_lib_decision_capture.sh"
FIXTURE_BASE="$REPO_ROOT/scripts/__tests__/fixtures/decisions/axis-gate"

setup() {
  export DECISION_TEST_MODE=1
  if [ -f "$LIB" ]; then
    # shellcheck source=/dev/null
    . "$LIB"
  fi
}

# ── (a) Undeclared axis is rejected ──────────────────────────────────────────

@test "TT4-axisgate: regenerate_decisions_index exits non-zero for log tagging undeclared axis" {
  # xfail: 2026-04-21-undeclared.md tags 'undeclared-axis' not in axes.md
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  cp "$FIXTURE_BASE/undeclared-axis-log/2026-04-21-undeclared.md" \
     "$TMPDIR_TEST/decisions/log/"
  cp "$FIXTURE_BASE/axes.md" "$TMPDIR_TEST/decisions/axes.md"
  INDEX_OUT="$TMPDIR_TEST/decisions/INDEX.md"

  run regenerate_decisions_index "$TMPDIR_TEST" "$INDEX_OUT"
  [ "$status" -ne 0 ]
  # stderr must name the undeclared axis
  [[ "$output" == *"undeclared-axis"* ]] || [[ "$stderr" == *"undeclared-axis"* ]]
  rm -rf "$TMPDIR_TEST"
}

@test "TT4-axisgate: error message cites [lib-decision] BLOCK: undeclared axis" {
  # xfail: error format per §4.3 strictness spec
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  cp "$FIXTURE_BASE/undeclared-axis-log/2026-04-21-undeclared.md" \
     "$TMPDIR_TEST/decisions/log/"
  cp "$FIXTURE_BASE/axes.md" "$TMPDIR_TEST/decisions/axes.md"
  INDEX_OUT="$TMPDIR_TEST/decisions/INDEX.md"

  run regenerate_decisions_index "$TMPDIR_TEST" "$INDEX_OUT" 2>&1
  combined="$output"
  [[ "$combined" == *"[lib-decision] BLOCK"* ]]
  rm -rf "$TMPDIR_TEST"
}

@test "TT4-axisgate: partial INDEX is not written when undeclared axis is detected" {
  # xfail: no partial writes — fail loud, no output file created
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  cp "$FIXTURE_BASE/undeclared-axis-log/2026-04-21-undeclared.md" \
     "$TMPDIR_TEST/decisions/log/"
  cp "$FIXTURE_BASE/axes.md" "$TMPDIR_TEST/decisions/axes.md"
  INDEX_OUT="$TMPDIR_TEST/decisions/INDEX.md"

  regenerate_decisions_index "$TMPDIR_TEST" "$INDEX_OUT" 2>/dev/null || true
  # INDEX must not have been created (or must be empty)
  [ ! -f "$INDEX_OUT" ] || [ ! -s "$INDEX_OUT" ]
  rm -rf "$TMPDIR_TEST"
}

# ── (b) New log tagging deprecated axis is rejected ───────────────────────────

@test "TT4-axisgate: new decision (post-deprecation-date) tagging deprecated axis is rejected" {
  # xfail: 2026-05-02-new-uses-deprecated.md dates after deprecated: 2026-05-01
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  cp "$FIXTURE_BASE/deprecated-new-log/2026-05-02-new-uses-deprecated.md" \
     "$TMPDIR_TEST/decisions/log/"
  cp "$FIXTURE_BASE/axes.md" "$TMPDIR_TEST/decisions/axes.md"
  INDEX_OUT="$TMPDIR_TEST/decisions/INDEX.md"

  run regenerate_decisions_index "$TMPDIR_TEST" "$INDEX_OUT"
  [ "$status" -ne 0 ]
  rm -rf "$TMPDIR_TEST"
}

# ── (c) Historical log on deprecated axis is preserved (§3.4 retention) ──────

@test "TT4-axisgate: historical log (pre-deprecation-date) tagging deprecated axis is preserved" {
  # xfail: 2026-04-01-old-decision.md predates deprecated: 2026-05-01
  # rollup passes, INDEX contains a row for the old decision,
  # preferences.md shows (deprecated) marker on the axis
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  cp "$FIXTURE_BASE/deprecated-old-log/2026-04-01-old-decision.md" \
     "$TMPDIR_TEST/decisions/log/"
  cp "$FIXTURE_BASE/axes.md" "$TMPDIR_TEST/decisions/axes.md"
  INDEX_OUT="$TMPDIR_TEST/decisions/INDEX.md"
  cat > "$TMPDIR_TEST/decisions/preferences.md" <<'EOF'
# Preferences — evelynn (personal)

Last calibrated: 2026-04-00 · Total decisions: 0 · Axes tracked: 2

## Axis: scope-vs-debt
  Samples: 0 (a: 0, b: 0, c: 0) · Match rate: 0% · Confidence: low
  Summary: Test.
  Notable misses: none yet.

## Axis: old-deprecated-axis (deprecated)
  Samples: 0 (a: 0, b: 0, c: 0) · Match rate: 0% · Confidence: low
  Summary: Deprecated axis — retained for historical reads.
  Notable misses: none yet.
EOF

  run regenerate_decisions_index "$TMPDIR_TEST" "$INDEX_OUT"
  [ "$status" -eq 0 ]
  # The historical log appears in INDEX
  run grep "old-decision" "$INDEX_OUT"
  [ "$status" -eq 0 ]
  rm -rf "$TMPDIR_TEST"
}

@test "TT4-axisgate: deprecated axis appears with (deprecated) marker in preferences.md after rollup" {
  # xfail: §3.4 retention — deprecated axis shown in preferences with marker
  [ -f "$LIB" ]
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/decisions/log"
  cp "$FIXTURE_BASE/deprecated-old-log/2026-04-01-old-decision.md" \
     "$TMPDIR_TEST/decisions/log/"
  cp "$FIXTURE_BASE/axes.md" "$TMPDIR_TEST/decisions/axes.md"
  PREF_FILE="$TMPDIR_TEST/decisions/preferences.md"
  cat > "$PREF_FILE" <<'EOF'
# Preferences — evelynn (personal)

Last calibrated: 2026-04-00 · Total decisions: 0 · Axes tracked: 2

## Axis: scope-vs-debt
  Samples: 0 (a: 0, b: 0, c: 0) · Match rate: 0% · Confidence: low
  Summary: Test.
  Notable misses: none yet.

## Axis: old-deprecated-axis (deprecated)
  Samples: 0 (a: 0, b: 0, c: 0) · Match rate: 0% · Confidence: low
  Summary: Deprecated axis — retained for historical reads.
  Notable misses: none yet.
EOF

  run rollup_preferences_counts "$TMPDIR_TEST" "$PREF_FILE"
  [ "$status" -eq 0 ]
  # (deprecated) marker must remain in preferences.md
  run grep "(deprecated)" "$PREF_FILE"
  [ "$status" -eq 0 ]
  rm -rf "$TMPDIR_TEST"
}
