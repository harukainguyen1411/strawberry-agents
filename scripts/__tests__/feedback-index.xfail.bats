# xfail: TT2 — scripts/feedback-index.sh schema validator + --check mode
# Plan: plans/approved/personal/2026-04-21-agent-feedback-system.md §Test plan TT2
# All tests in this file are expected to FAIL until T2 implements scripts/feedback-index.sh.
# Run with: bats scripts/__tests__/feedback-index.xfail.bats
#
# Guards: T2 DoD bullets 1-4 (five valid fixtures exit 0; three malformed fixtures exit
# non-zero with faulty field in stderr; rendering twice produces byte-identical INDEX).
# Also guards Invariant 4 (idempotent index).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/feedback-index.sh"
  FIXTURES_VALID="$REPO_ROOT/scripts/__tests__/fixtures/feedback/valid"
  FIXTURES_MALFORMED="$REPO_ROOT/scripts/__tests__/fixtures/feedback/malformed"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Script presence + syntax
# ---------------------------------------------------------------------------

@test "TT2: feedback-index.sh exists" {
  # xfail: scripts/feedback-index.sh does not exist yet (T2 not implemented)
  [ -f "$SCRIPT" ]
}

@test "TT2: feedback-index.sh passes bash -n syntax check" {
  # xfail: depends on script existing
  [ -f "$SCRIPT" ]
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# --check mode: valid fixtures must exit 0
# ---------------------------------------------------------------------------

@test "TT2: --check passes on valid fixture: 2026-04-21-0900-sona-orianna-signing-latency" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_VALID/2026-04-21-0900-sona-orianna-signing-latency.md"
  [ "$status" -eq 0 ]
}

@test "TT2: --check passes on valid fixture: 2026-04-21-0915-sona-orianna-signing-followups" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_VALID/2026-04-21-0915-sona-orianna-signing-followups.md"
  [ "$status" -eq 0 ]
}


@test "TT2: --check passes on valid fixture: 2026-04-21-1000-sona-phase-discipline-approved-vs-in-progress" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_VALID/2026-04-21-1000-sona-phase-discipline-approved-vs-in-progress.md"
  [ "$status" -eq 0 ]
}

@test "TT2: --check passes on valid fixture: 2026-04-21-1100-sona-viktor-context-ceiling-batched-impl" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_VALID/2026-04-21-1100-sona-viktor-context-ceiling-batched-impl.md"
  [ "$status" -eq 0 ]
}

@test "TT2: --check passes on valid fixture: 2026-04-22-0900-sona-coordinator-verify-qa-claims" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_VALID/2026-04-22-0900-sona-coordinator-verify-qa-claims.md"
  [ "$status" -eq 0 ]
}

@test "TT2: --check passes on all five valid fixtures in directory mode" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check --dir "$FIXTURES_VALID"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# --check mode: malformed fixtures must exit non-zero, naming the faulty field
# ---------------------------------------------------------------------------

@test "TT2: --check fails on missing-severity fixture and names 'severity' in stderr" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_MALFORMED/missing-severity.md"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "severity" ]] || [[ "$stderr" =~ "severity" ]] || echo "$output" | grep -qi "severity"
}

@test "TT2: --check fails on invalid-category fixture and names 'category' in stderr" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_MALFORMED/invalid-category.md"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "category" ]] || echo "$output" | grep -qi "category"
}

@test "TT2: --check fails on missing-what-went-wrong fixture and names the missing section in stderr" {
  # xfail: scripts/feedback-index.sh does not exist yet
  run bash "$SCRIPT" --check "$FIXTURES_MALFORMED/missing-what-went-wrong.md"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "What went wrong" ]] || [[ "$output" =~ "what went wrong" ]] || echo "$output" | grep -qi "what went wrong"
}

# ---------------------------------------------------------------------------
# Idempotency (Invariant 4): running index generation twice produces zero diff
# ---------------------------------------------------------------------------

@test "TT2: rendering index twice on valid fixture set produces byte-identical output (Invariant 4)" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX-run1.md"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX-run2.md"
  [ "$status" -eq 0 ]
  run diff "$TMP_DIR/INDEX-run1.md" "$TMP_DIR/INDEX-run2.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# INDEX output structure: column headers per §D3
# ---------------------------------------------------------------------------

@test "TT2: rendered INDEX contains required column headers per §D3" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "Severity.*Date.*Author.*Category.*Slug.*Cost" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

@test "TT2: rendered INDEX contains Open summary line per §D3" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "Open: [0-9]+ \| High: [0-9]+ \| Medium: [0-9]+ \| Low: [0-9]+" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

@test "TT2: rendered INDEX contains Graduated summary line per §D3" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "Graduated \(this week\): [0-9]+" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

@test "TT2: rendered INDEX contains Stale summary line per §D3" {
  # xfail: scripts/feedback-index.sh does not exist yet
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --dir "$FIXTURES_VALID" --out "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
  run grep -E "Stale \(pending prune\): [0-9]+" "$TMP_DIR/INDEX.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Invariant 1 audit mode: --check --audit-history detects rogue entries
# (entries whose introducing commit is not prefixed chore: feedback*)
# ---------------------------------------------------------------------------

@test "TT2: --check --audit-history mode is supported (does not crash)" {
  # xfail: scripts/feedback-index.sh does not exist yet (audit-history mode part of T2 DoD per TT3 §c)
  [ -f "$SCRIPT" ]
  # We only assert the mode exits cleanly or fails with a recognised error;
  # full audit coverage is in TT3.
  run bash "$SCRIPT" --check --audit-history --dir "$FIXTURES_VALID"
  # Either exit 0 (clean) or exit 2 (mode unsupported but explicit) — not a segfault
  [ "$status" -le 2 ]
}

# ---------------------------------------------------------------------------
# Category enum closure: valid categories from §D1 pass; unknown fails
# ---------------------------------------------------------------------------

@test "TT2: all valid §D1 category enum values are accepted by --check" {
  # xfail: scripts/feedback-index.sh does not exist yet
  valid_categories=(
    "hook-friction"
    "schema-surprise"
    "tool-missing"
    "tool-permission"
    "doc-stale"
    "review-loop"
    "coordinator-discipline"
    "retry-loop"
    "context-loss"
    "other"
  )
  for cat in "${valid_categories[@]}"; do
    tmpfile="$TMP_DIR/valid-cat-$cat.md"
    cat > "$tmpfile" <<FIXTURE
---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: $cat
severity: low
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Category test $cat

## What went wrong

Category enum test fixture for category: $cat.

## Suggestion

- No suggestion needed.

## Why I'm writing this now

Test fixture only.
FIXTURE
    run bash "$SCRIPT" --check "$tmpfile"
    [ "$status" -eq 0 ]
  done
}

@test "TT2: unknown category value fails --check" {
  # xfail: scripts/feedback-index.sh does not exist yet
  tmpfile="$TMP_DIR/bad-cat.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: not-a-valid-category
severity: low
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Category enum failure test

## What went wrong

Invalid category to trigger --check failure.

## Suggestion

- Fix: use a valid category.

## Why I'm writing this now

Test fixture only.
FIXTURE
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Severity enum closure: valid values pass; unknown fails
# ---------------------------------------------------------------------------

@test "TT2: severity enum values low/medium/high all pass --check" {
  for sev in low medium high; do
    tmpfile="$TMP_DIR/sev-$sev.md"
    cat > "$tmpfile" <<FIXTURE
---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: other
severity: $sev
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Severity test $sev

## What went wrong

Severity enum test fixture.

## Suggestion

- No suggestion.

## Why I'm writing this now

Test fixture only.
FIXTURE
    run bash "$SCRIPT" --check "$tmpfile"
    [ "$status" -eq 0 ]
  done
}

@test "TT2: unknown severity value fails --check" {
  # xfail: scripts/feedback-index.sh does not exist yet
  tmpfile="$TMP_DIR/bad-sev.md"
  cat > "$tmpfile" <<'FIXTURE'
---
date: 2026-04-21
time: "09:00"
author: sona
concern: work
category: other
severity: critical
friction_cost_minutes: 5
related_feedback: []
state: open
---

# Severity enum failure test

## What went wrong

Invalid severity to trigger --check failure.

## Suggestion

- Fix: use low, medium, or high.

## Why I'm writing this now

Test fixture only.
FIXTURE
  run bash "$SCRIPT" --check "$tmpfile"
  [ "$status" -ne 0 ]
}
