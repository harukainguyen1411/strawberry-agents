#!/usr/bin/env bats
# xfail: TT2-rollup — rollup_preferences_counts idempotency + summary-prose
# preservation.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md
#       §4.3, §3.2, TT2-rollup
# xfail: all tests are expected to fail until T2 implements rollup_preferences_counts.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/_lib_decision_capture.sh"
FIXTURE_BASE="$REPO_ROOT/scripts/__tests__/fixtures/decisions/rollup-12"

setup() {
  export DECISION_TEST_MODE=1
  TMPDIR_TEST="$(mktemp -d)"
  # Build coordinator dir from fixtures
  COORD_DECISIONS="$TMPDIR_TEST/decisions"
  mkdir -p "$COORD_DECISIONS/log"
  cp -r "$FIXTURE_BASE/log/." "$COORD_DECISIONS/log/"
  cp "$FIXTURE_BASE/preferences.before.md" "$COORD_DECISIONS/preferences.md"
  cat > "$COORD_DECISIONS/axes.md" <<'EOF'
# Axes — evelynn

## scope-vs-debt
  Added: 2026-04-21
  Definition: Cleanness vs debt.

## explicit-vs-implicit
  Added: 2026-04-21
  Definition: Declare vs infer.

## hand-curated-vs-automated
  Added: 2026-04-21
  Definition: Human vs machine.
EOF
  if [ -f "$LIB" ]; then
    # shellcheck source=/dev/null
    . "$LIB"
  fi
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── (a) scope-vs-debt counts after rollup ────────────────────────────────────

@test "TT2-rollup: scope-vs-debt Samples line is 7 (a:4, b:1, c:2) Match rate 86% Confidence medium" {
  # xfail: requires rollup_preferences_counts (T2) with corrected match_rate formula.
  # Fixture now has 7 scope-vs-debt files: svd-1..7.
  # match_count=6 (svd-5 is the only miss); wrong formula (count_a/total = 4/7 = 57%)
  # must be replaced by match_count/total = 6/7 = 86%.
  # svd-4 (coordinator_pick:b, duong_pick:b, match:true) and
  # svd-7 (coordinator_pick:c, duong_pick:c, match:true) are the discriminating cases.
  [ -f "$LIB" ]
  run rollup_preferences_counts "$TMPDIR_TEST" "$COORD_DECISIONS/preferences.md"
  [ "$status" -eq 0 ]
  run grep "Samples: 7 (a: 4, b: 1, c: 2)" "$COORD_DECISIONS/preferences.md"
  [ "$status" -eq 0 ]
  run grep "Match rate: 86%" "$COORD_DECISIONS/preferences.md"
  [ "$status" -eq 0 ]
  run grep "Confidence: medium" "$COORD_DECISIONS/preferences.md"
  [ "$status" -eq 0 ]
}

# ── (b) Idempotency ───────────────────────────────────────────────────────────

@test "TT2-rollup: running rollup_preferences_counts twice produces byte-identical preferences.md" {
  # xfail: idempotency invariant — two runs produce same bytes
  [ -f "$LIB" ]
  rollup_preferences_counts "$TMPDIR_TEST" "$COORD_DECISIONS/preferences.md"
  hash1="$(md5 -q "$COORD_DECISIONS/preferences.md" 2>/dev/null || md5sum "$COORD_DECISIONS/preferences.md" | cut -d' ' -f1)"
  rollup_preferences_counts "$TMPDIR_TEST" "$COORD_DECISIONS/preferences.md"
  hash2="$(md5 -q "$COORD_DECISIONS/preferences.md" 2>/dev/null || md5sum "$COORD_DECISIONS/preferences.md" | cut -d' ' -f1)"
  [ "$hash1" = "$hash2" ]
}

# ── (c) Summary prose preservation ───────────────────────────────────────────

@test "TT2-rollup: hand-curated Summary prose with italics survives rollup byte-identical" {
  # xfail: prose preservation invariant — _curated_ marker must survive
  [ -f "$LIB" ]
  # Capture the prose before rollup
  prose_before="$(grep '_curated_ prose is hand-maintained' "$COORD_DECISIONS/preferences.md" || echo '')"
  rollup_preferences_counts "$TMPDIR_TEST" "$COORD_DECISIONS/preferences.md"
  prose_after="$(grep '_curated_ prose is hand-maintained' "$COORD_DECISIONS/preferences.md" || echo '')"
  [ -n "$prose_before" ]
  [ "$prose_before" = "$prose_after" ]
}

@test "TT2-rollup: markdown link in Summary prose survives rollup" {
  # xfail: link syntax [a link](https://example.com) must not be stripped
  [ -f "$LIB" ]
  rollup_preferences_counts "$TMPDIR_TEST" "$COORD_DECISIONS/preferences.md"
  run grep '\[a link\](https://example.com)' "$COORD_DECISIONS/preferences.md"
  [ "$status" -eq 0 ]
}

@test "TT2-rollup: bold and italic markers in Summary prose survive rollup" {
  # xfail: *Italics* and **bold** must not be stripped by the rollup pass
  [ -f "$LIB" ]
  rollup_preferences_counts "$TMPDIR_TEST" "$COORD_DECISIONS/preferences.md"
  run grep '\*Italics\* and \*\*bold\*\*' "$COORD_DECISIONS/preferences.md"
  [ "$status" -eq 0 ]
}

# ── Notable misses accuracy ───────────────────────────────────────────────────

@test "TT2-rollup: Notable misses contains the correct miss slug for scope-vs-debt" {
  # xfail: 2026-04-05-svd-5 is the only miss in scope-vs-debt fixture
  [ -f "$LIB" ]
  rollup_preferences_counts "$TMPDIR_TEST" "$COORD_DECISIONS/preferences.md"
  run grep '2026-04-05-svd-5' "$COORD_DECISIONS/preferences.md"
  [ "$status" -eq 0 ]
}
