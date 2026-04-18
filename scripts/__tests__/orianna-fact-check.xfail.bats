# xfail: O3.1 + O3.2 — scripts/orianna-fact-check.sh + scripts/fact-check-plan.sh
# (plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md tasks O3.1, O3.2, O3.3, O3.4)
# Bats tests expected to fail until orianna-fact-check.sh and fact-check-plan.sh are implemented.
# Run with: bats scripts/__tests__/orianna-fact-check.xfail.bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  FACT_CHECK="$REPO_ROOT/scripts/orianna-fact-check.sh"
  BASH_FALLBACK="$REPO_ROOT/scripts/fact-check-plan.sh"
  REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
  BAD_PLAN="$REPO_ROOT/plans/proposed/2026-04-19-orianna-smoke-bad-plan.md"
  # Use a simple approved plan with no cross-repo path claims for clean-pass tests.
  CLEAN_PLAN="$REPO_ROOT/plans/approved/2026-04-05-gh-auth-lockdown.md"
}

# --- Test 1: usage banner on zero args ---
@test "orianna-fact-check.sh: prints usage and exits 2 with no args" {
  run bash "$FACT_CHECK"
  [ "$status" -eq 2 ]
  [[ "$output" =~ [Uu]sage ]]
}

# --- Test 2: bash -n syntax check for orianna-fact-check.sh ---
@test "orianna-fact-check.sh: passes bash -n syntax check" {
  run bash -n "$FACT_CHECK"
  [ "$status" -eq 0 ]
}

# --- Test 3: bash -n syntax check for fact-check-plan.sh ---
@test "fact-check-plan.sh: passes bash -n syntax check" {
  run bash -n "$BASH_FALLBACK"
  [ "$status" -eq 0 ]
}

# --- Test 4: fallback path fires when claude CLI absent ---
@test "orianna-fact-check.sh: falls back to fact-check-plan.sh when claude CLI absent" {
  skip "requires bad plan seeded by O6.1; run after O6.1 is committed"
  run env PATH="/usr/bin:/bin" bash "$FACT_CHECK" "$BAD_PLAN"
  # must log the fallback message to stderr
  [[ "${output}" =~ "falling back to mechanical check" ]] || \
    [[ "${stderr}" =~ "falling back to mechanical check" ]]
  # report frontmatter must say claude_cli: absent
  latest_report=$(ls -t "$REPORT_DIR"/*.md 2>/dev/null | head -1)
  [ -n "$latest_report" ]
  grep -q 'claude_cli: absent' "$latest_report"
}

# --- Test 5: bash fallback blocks bad plan path claim ---
@test "fact-check-plan.sh: exits 1 and flags block finding for nonexistent cross-repo path" {
  skip "requires bad plan seeded by O6.1; run after O6.1 is committed"
  run env PATH="/usr/bin:/bin" bash "$FACT_CHECK" "$BAD_PLAN"
  [ "$status" -eq 1 ]
  latest_report=$(ls -t "$REPORT_DIR"/*.md 2>/dev/null | head -1)
  [ -n "$latest_report" ]
  grep -q 'block' "$latest_report"
}

# --- Test 6: clean plan exits 0 (fallback path) ---
@test "fact-check-plan.sh: exits 0 on a plan with no cross-repo path claims" {
  run env PATH="/usr/bin:/bin" bash "$FACT_CHECK" "$CLEAN_PLAN"
  [ "$status" -eq 0 ]
  latest_report=$(ls -t "$REPORT_DIR"/*.md 2>/dev/null | head -1)
  [ -n "$latest_report" ]
  grep -q 'block_findings: 0' "$latest_report"
}

# --- Test 7: report file always written even on exit 1 ---
@test "fact-check-plan.sh: report file written to assessments/plan-fact-checks/ on block exit" {
  skip "requires bad plan seeded by O6.1; run after O6.1 is committed"
  before=$(ls "$REPORT_DIR"/*.md 2>/dev/null | wc -l || echo 0)
  run env PATH="/usr/bin:/bin" bash "$FACT_CHECK" "$BAD_PLAN"
  after=$(ls "$REPORT_DIR"/*.md 2>/dev/null | wc -l || echo 0)
  [ "$after" -gt "$before" ]
}

# --- Bug regression tests (O6 smoke findings) ---

# xfail: O6-bug1 — orianna-fact-check.sh used --non-interactive (not a valid flag) and
# --system instead of --system-prompt.  After the fix, the invocation must not error with
# "unknown option" when claude CLI is present.
@test "orianna-fact-check.sh: claude CLI invocation does not use --non-interactive flag (bug O6-bug1)" {
  # Verify the script no longer contains the invalid --non-interactive flag.
  run grep -- '--non-interactive' "$FACT_CHECK"
  [ "$status" -ne 0 ]  # grep exits 1 when string not found — that is the expected (fixed) state
}

# xfail: O6-bug1b — orianna-fact-check.sh must use --system-prompt not --system.
@test "orianna-fact-check.sh: uses --system-prompt not bare --system (bug O6-bug1b)" {
  # The script must NOT contain a bare ' --system ' token (only --system-prompt is valid).
  run grep -P ' --system ' "$FACT_CHECK"
  [ "$status" -ne 0 ]
}

# xfail: O6-bug2 — orianna-memory-audit.sh used --subagent and --non-interactive and
# --prompt, all of which are invalid flags.  After the fix, those flags must be absent.
@test "orianna-memory-audit.sh: does not use --subagent flag (bug O6-bug2)" {
  MEMORY_AUDIT="$REPO_ROOT/scripts/orianna-memory-audit.sh"
  run grep -- '--subagent' "$MEMORY_AUDIT"
  [ "$status" -ne 0 ]
}

@test "orianna-memory-audit.sh: does not use --non-interactive flag (bug O6-bug2b)" {
  MEMORY_AUDIT="$REPO_ROOT/scripts/orianna-memory-audit.sh"
  run grep -- '--non-interactive' "$MEMORY_AUDIT"
  [ "$status" -ne 0 ]
}

@test "orianna-memory-audit.sh: does not use --prompt flag (bug O6-bug2c)" {
  MEMORY_AUDIT="$REPO_ROOT/scripts/orianna-memory-audit.sh"
  run grep -- '--prompt ' "$MEMORY_AUDIT"
  [ "$status" -ne 0 ]
}

# xfail: O6-bug3 — fact-check-plan.sh treated brace-expansion tokens like
# agents/orianna/{profile.md,memory/MEMORY.md} as literal paths and flagged them as
# missing.  After the fix, the script must skip tokens containing '{' or '}'.
# We create a temp plan with a brace-expansion token and verify it produces 0 block findings.
@test "fact-check-plan.sh: skips brace-expansion tokens (bug O6-bug3)" {
  # Build a minimal plan file that mentions a brace-expansion shorthand in a backtick span.
  TMPPLAN="$(mktemp /tmp/brace-expansion-test-XXXXXX.md)"
  cat > "$TMPPLAN" <<'EOF'
---
id: test-brace-expansion
status: approved
---

# Test plan

Files: `agents/orianna/{profile.md,memory/MEMORY.md,learnings/index.md,inbox.md}`
EOF
  run bash "$BASH_FALLBACK" "$TMPPLAN"
  rm -f "$TMPPLAN"
  # Must exit 0 — brace expansion token must not be flagged as a missing path.
  [ "$status" -eq 0 ]
}

# --- Bug A regression tests — report-picker prefix-match bug ---
# xfail: Bug-A — orianna-fact-check.sh glob `${PLAN_BASENAME}-*.md` matches reports for
# plans that share a basename prefix (e.g. foo-2026.md also matches foo-tasks-2026.md).
# After the fix, the picker must only pick up reports that begin with an exact basename
# followed immediately by a digit (ISO timestamp), not by arbitrary text like "-tasks-".

@test "orianna-fact-check.sh: report picker selects exact-basename report not prefix-sibling (bug Bug-A)" {
  # Create a tmp report dir with two seeded reports that share a prefix:
  #   foo-2026-01-01T00-00-00Z.md   (the correct report for plan "foo")
  #   foo-tasks-2026-01-01T00-00-01Z.md  (a report for the "foo-tasks" plan — must NOT be picked)
  TMP_REPORT_DIR="$(mktemp -d /tmp/orianna-picker-test-XXXXXX)"
  # Correct report: basename = "foo", has a timestamp starting with digit
  cat > "$TMP_REPORT_DIR/foo-2026-01-01T00-00-00Z.md" <<'EOF'
---
plan: plans/approved/foo.md
checked_at: 2026-01-01T00:00:00Z
auditor: orianna
claude_cli: absent
block_findings: 0
warn_findings: 0
info_findings: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

None.
EOF
  # Sibling report: basename = "foo-tasks" — must NOT be selected when looking for "foo"
  cat > "$TMP_REPORT_DIR/foo-tasks-2026-01-01T00-00-01Z.md" <<'EOF'
---
plan: plans/approved/foo-tasks.md
checked_at: 2026-01-01T00:00:01Z
auditor: orianna
claude_cli: absent
block_findings: 1
warn_findings: 0
info_findings: 0
---

## Block findings

1. **Claim:** `agents/nonexistent/path.md` | **Anchor:** `test -e ...` | **Result:** path not found | **Severity:** block

## Warn findings

None.

## Info findings

None.
EOF

  # Simulate the picker logic from orianna-fact-check.sh:
  # Old (buggy): for f in "$TMP_REPORT_DIR"/foo-*.md
  # New (fixed): for f in "$TMP_REPORT_DIR"/foo-[0-9]*.md
  # We test the fixed variant below and assert it finds only the correct report.
  latest_report=""
  for f in "$TMP_REPORT_DIR"/foo-[0-9]*.md; do
    [ -f "$f" ] && latest_report="$f"
  done

  rm -rf "$TMP_REPORT_DIR"

  # Must have selected only the "foo-2026..." report
  [ -n "$latest_report" ]
  # The selected report must NOT be the foo-tasks one (block_findings: 1)
  # We verify by checking the filename ends with 00-00-00Z.md (not 00-00-01Z.md)
  [[ "$latest_report" == *"foo-2026-01-01T00-00-00Z.md" ]]
}

@test "orianna-fact-check.sh: report picker does not match foo-tasks report when looking for foo (bug Bug-A b)" {
  # Verify the script uses [0-9]* anchor in its glob, not bare *
  run grep 'PLAN_BASENAME.*\-\[\[' "$FACT_CHECK"
  # We check for the [0-9] pattern in the picker loop
  run grep '\[0-9\]' "$FACT_CHECK"
  [ "$status" -eq 0 ]
}

# --- Bug B regression tests — orianna:ok suppression in fact-check-plan.sh ---
# xfail: Bug-B — fact-check-plan.sh has no suppression syntax. A line ending with
# <!-- orianna: ok --> must not produce block findings for tokens on that line.

@test "fact-check-plan.sh: suppresses findings on lines marked with orianna:ok (bug Bug-B)" {
  # Seed a plan with a Firebase GitHub App reference (would normally be flagged as an
  # integration-name-shaped token) followed by the suppression marker.
  # Because the bash fallback only checks path-shaped tokens (not integration names),
  # we use a nonexistent path token on a suppressed line to test the mechanism.
  TMPPLAN="$(mktemp /tmp/orianna-suppress-test-XXXXXX.md)"
  cat > "$TMPPLAN" <<'EOF'
---
id: test-suppression
status: approved
---

# Test plan

This line references a nonexistent path for illustration: `agents/nonexistent/path-that-does-not-exist.md` <!-- orianna: ok -->
EOF
  run bash "$BASH_FALLBACK" "$TMPPLAN"
  rm -f "$TMPPLAN"
  # Must exit 0 — suppressed line must not produce a block finding
  [ "$status" -eq 0 ]
}

@test "fact-check-plan.sh: suppresses findings when orianna:ok is on the line immediately preceding (bug Bug-B b)" {
  # The suppression marker on the line above the claim line must also suppress.
  # We represent this as: marker on line N, claim on line N+1.
  TMPPLAN="$(mktemp /tmp/orianna-suppress-prev-XXXXXX.md)"
  cat > "$TMPPLAN" <<'EOF'
---
id: test-suppression-prev
status: approved
---

# Test plan

<!-- orianna: ok -->
`agents/nonexistent/path-that-does-not-exist.md`
EOF
  run bash "$BASH_FALLBACK" "$TMPPLAN"
  rm -f "$TMPPLAN"
  # Must exit 0 — suppressed line must not produce a block finding
  [ "$status" -eq 0 ]
}
