# xfail: TT2-bind — §D12 dashboard read-contract bind points
# Plan: plans/approved/personal/2026-04-21-agent-feedback-system.md §Test plan TT2-bind
# Guards: §D12 bind contract for plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md §Q7
# All tests expected to FAIL until T2 implements scripts/feedback-index.sh.
# Run with: bats scripts/__tests__/feedback-index-bind-contract.xfail.bats
#
# §D12 bind-points (breaking-change-locked):
#   (a) Severity is column 1 in header row
#   (b) Date is column 2 in header row
#   (c) Summary line: "Open: N | High: N | Medium: N | Low: N"
#   (d) Summary line: "Graduated (this week): N"
#   (e) Mutation-simulation: FEEDBACK_INDEX_RENAME_SEVERITY=Priority causes bind-point assertion to FAIL

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/feedback-index.sh"
  FIXTURES_VALID="$REPO_ROOT/scripts/__tests__/fixtures/feedback/valid"
  FIXTURES_BIND="$REPO_ROOT/scripts/__tests__/fixtures/feedback/bind-mutation"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# (a) Severity column must be column 1 — not aliased, not reordered
# ---------------------------------------------------------------------------

@test "TT2-bind (a): INDEX header row has 'Severity' as column 1" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  # The header line should start with '| Severity'
  run grep -E "^\| Severity" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

@test "TT2-bind (a): INDEX header row does not use 'Priority' alias for Severity" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "^\| Priority" "$TMP_DIR/INDEX.md"
  # Must NOT match — Priority is not a valid column name
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# (b) Date column must be column 2 — not aliased, not reordered
# ---------------------------------------------------------------------------

@test "TT2-bind (b): INDEX header row has 'Date' as column 2" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  # Column 2 in a markdown table: pattern is '| col1 | col2 |...'
  run grep -E "^\| Severity\s*\| Date" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (c) Summary line: "Open: N | High: N | Medium: N | Low: N"
#     Four keys exactly, pipe-delimited, integer values
# ---------------------------------------------------------------------------

@test "TT2-bind (c): INDEX contains Open summary line with four pipe-delimited key: int pairs" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "^Open: [0-9]+ \| High: [0-9]+ \| Medium: [0-9]+ \| Low: [0-9]+$" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

@test "TT2-bind (c): Open summary line keys are exactly Open, High, Medium, Low — not aliased" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  # No line with 'Priority' or 'Critical' substitutions
  run grep -E "Open: [0-9]+ \| (Priority|Critical|Sev):" "$TMP_DIR/INDEX.md"
  [ "$status" -ne 0 ]
}

@test "TT2-bind (c): Open summary count matches actual high+medium+low count from fixture set" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  # Five valid fixtures: 1 high (signing-latency), 4 medium, 0 low
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "^Open: 5 \| High: 1 \| Medium: 4 \| Low: 0$" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (d) Summary line: "Graduated (this week): N"
# ---------------------------------------------------------------------------

@test "TT2-bind (d): INDEX contains Graduated summary line with integer" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "^Graduated \(this week\): [0-9]+$" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

@test "TT2-bind (d): Graduated summary line uses exact wording '(this week)' — not aliased" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  # Reject aliased forms
  run grep -E "^Graduated \(7d\):|^Graduated \(week\):" "$TMP_DIR/INDEX.md"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# (e) Mutation-simulation: FEEDBACK_INDEX_RENAME_SEVERITY=Priority
#     When the renderer is invoked with this env var, a bind-contract check
#     that asserts "Severity" column is present should FAIL.
#     This test proves the contract is not aspirational.
# ---------------------------------------------------------------------------

@test "TT2-bind (e): mutation-simulation — FEEDBACK_INDEX_RENAME_SEVERITY=Priority causes Severity bind check to trip" {
  # xfail: scripts/feedback-index.sh does not exist yet (and does not support rename-simulation env var yet)
  [ -f "$SCRIPT" ]
  # Generate a "mutated" index with the rename env var
  run env FEEDBACK_INDEX_RENAME_SEVERITY=Priority bash "$SCRIPT" --dir "$FIXTURES_BIND" --out "$TMP_DIR/INDEX-mutated.md"
  # Script may succeed (0) or indicate the rename was applied
  # The critical assertion: the mutated INDEX should NOT contain '| Severity' as column 1
  if [ -f "$TMP_DIR/INDEX-mutated.md" ]; then
    run grep -E "^\| Severity" "$TMP_DIR/INDEX-mutated.md"
    # If the rename was applied, this grep should find nothing (status != 0)
    [ "$status" -ne 0 ]
  else
    # Script did not produce output — the mutation mode is not yet implemented;
    # this is the expected xfail state
    false
  fi
}

@test "TT2-bind (e): without mutation env var, Severity column is present (baseline)" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_BIND" --out "$TMP_DIR/INDEX-baseline.md"
  [ "$status" -eq 0 ]
  run grep -E "^\| Severity" "$TMP_DIR/INDEX-baseline.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Columns NOT in bind contract (Author, Category, Slug, Cost) — present but not locked
# We assert presence only as documentation; these can change without paired dashboard work.
# ---------------------------------------------------------------------------

@test "TT2-bind: INDEX header contains Author, Category, Slug, Cost columns (non-locked but present)" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "Author.*Category.*Slug.*Cost" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}
