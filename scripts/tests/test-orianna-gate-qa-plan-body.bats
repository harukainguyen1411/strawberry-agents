#!/usr/bin/env bats
# scripts/tests/test-orianna-gate-qa-plan-body.bats
#
# T7a — xfail tests: Orianna gate v2 ## QA Plan body-section linter.
#
# Plan: plans/approved/personal/2026-04-25-structured-qa-pipeline.md §T7a
# Test plan items: Test 2 (qa_plan: required + ## QA Plan absent/incomplete → REJECT)
#                  Test 3 (grandfather: pre-cutover plan missing qa_plan → PASS with WARN)
#
# Required sub-headings per D2:
#   ### Acceptance criteria
#   ### Happy path (user flow)
#   ### Failure modes (what could break)
#   ### QA artifacts expected
#
# xfail: all assertions fail until T7b lands the body-section linter in
#        scripts/hooks/pre-commit-zz-plan-structure.sh (check_qa_plan_body).
#        The grandfather branch (T7c/T7d) is in the companion file
#        test-orianna-gate-qa-plan-grandfather.bats.
#
# Run: bats scripts/tests/test-orianna-gate-qa-plan-body.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/_lib_plan_structure.sh"

# The four required sub-heading strings (exact match from plan §D2)
SUBHEADING_ACCEPTANCE="### Acceptance criteria"
SUBHEADING_HAPPY="### Happy path (user flow)"
SUBHEADING_FAILURE="### Failure modes (what could break)"
SUBHEADING_ARTIFACTS="### QA artifacts expected"

# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------

# make_plan_required <path> <body_after_frontmatter>
make_plan_required() {
  _path="$1"
  _body="$2"
  cat > "$_path" <<PLAN_EOF
---
status: proposed
concern: personal
owner: test-author
created: 2026-04-25
tests_required: true
qa_plan: required
qa_co_author: lulu
---

${_body}
PLAN_EOF
}

# make_plan_inline <path> <body_after_frontmatter>
make_plan_inline() {
  _path="$1"
  _body="$2"
  cat > "$_path" <<PLAN_EOF
---
status: proposed
concern: personal
owner: test-author
created: 2026-04-25
tests_required: true
qa_plan: inline
qa_co_author: lulu
---

${_body}
PLAN_EOF
}

full_qa_section() {
  cat <<'QA_EOF'
## QA Plan

### Acceptance criteria
- The system rejects a plan with qa_plan: required but missing the body section.
- The system accepts a plan with qa_plan: required and all four sub-headings present.

### Happy path (user flow)
1. Author creates a plan with qa_plan: required.
2. Author writes the full ## QA Plan section with all four sub-headings.
3. Orianna promotes the plan.

### Failure modes (what could break)
- ## QA Plan section absent: trigger → REJECT with error naming the missing section.
- Sub-heading missing: trigger → REJECT with error naming the specific missing sub-heading.

### QA artifacts expected
- Stage 2 (draft-PR smoke): no UI surface — smoke skipped.
- Stage 3 (pre-merge): script-level test run only.
- Design reference: n/a — backend surface.
QA_EOF
}

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  TMP_DIR="$(mktemp -d)"
  # Detect implementation: T7b adds check_qa_plan_body to _lib_plan_structure.sh.
  IMPL_PRESENT=0
  if grep -q 'check_qa_plan_body' "$LIB" 2>/dev/null; then
    IMPL_PRESENT=1
    # shellcheck source=/dev/null
    . "$LIB"
  fi
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# T7a-1 — qa_plan: required + all 4 sub-headings present → passes body check
# ---------------------------------------------------------------------------

@test "T7a-1: qa_plan: required + full ## QA Plan with all 4 sub-headings → passes" {
  # xfail: check_qa_plan_body not implemented yet (T7b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"

  PLAN="$TMP_DIR/required-all-subheadings.md"
  make_plan_required "$PLAN" "# Full QA Plan

$(full_qa_section)
"

  run check_qa_plan_body "$PLAN"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T7a-2 — qa_plan: required + ## QA Plan present but missing all sub-headings → BLOCK
# ---------------------------------------------------------------------------

@test "T7a-2: qa_plan: required + ## QA Plan section present but no sub-headings → BLOCK" {
  # xfail: check_qa_plan_body not implemented yet (T7b)
  # Primary Test 2 assertion from the plan's §Test plan.
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"

  PLAN="$TMP_DIR/required-no-subheadings.md"
  make_plan_required "$PLAN" "# QA Plan Without Sub-headings

## QA Plan

This section exists but has no required sub-headings — it is just a paragraph.
"

  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  # Error must name the missing section
  [[ "$output" == *"QA Plan"* ]]
}

# ---------------------------------------------------------------------------
# T7a-3 — qa_plan: required + ## QA Plan section entirely absent → BLOCK
# ---------------------------------------------------------------------------

@test "T7a-3: qa_plan: required + ## QA Plan section entirely absent → BLOCK with section name" {
  # xfail: check_qa_plan_body not implemented yet (T7b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"

  PLAN="$TMP_DIR/required-no-section.md"
  make_plan_required "$PLAN" "# No QA Section At All

There is no ## QA Plan section in this body. The check should fail.
"

  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  # Error must cite the missing heading name
  [[ "$output" == *"## QA Plan"* ]] || [[ "$output" == *"QA Plan"* ]]
}

# ---------------------------------------------------------------------------
# T7a-4 — qa_plan: inline + single paragraph (no sub-headings) → passes (inline exempt)
# ---------------------------------------------------------------------------

@test "T7a-4: qa_plan: inline + single-paragraph body section (no sub-headings) → passes" {
  # xfail: check_qa_plan_body not implemented yet (T7b)
  # inline value permits a one-paragraph section per D2 — sub-headings NOT required.
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"

  PLAN="$TMP_DIR/inline-single-para.md"
  make_plan_inline "$PLAN" "# Inline Surface Plan

## QA Plan

Trivial copy change — one CSS class rename, no layout change. Acceptance: text appears
correct in staging browser; no regressions on existing routes.
"

  run check_qa_plan_body "$PLAN"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T7a-5 — qa_plan: required + only 3 of 4 sub-headings → BLOCK naming specific missing one
# ---------------------------------------------------------------------------

@test "T7a-5: qa_plan: required + 3 of 4 sub-headings present → BLOCK naming the missing sub-heading" {
  # xfail: check_qa_plan_body not implemented yet (T7b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"

  PLAN="$TMP_DIR/required-missing-artifacts.md"
  make_plan_required "$PLAN" "# Missing Artifacts Sub-heading

## QA Plan

### Acceptance criteria
- Route renders without errors.
- Form submits successfully.

### Happy path (user flow)
1. User navigates to /settings.
2. User updates email field.
3. User sees success toast.

### Failure modes (what could break)
- Network timeout on submit: trigger → error toast with retry button.

### QA artifacts expected sub-heading is intentionally omitted here.
"
  # Note: the last line is a paragraph, not the required sub-heading

  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  # Error must name the specific missing sub-heading
  [[ "$output" == *"QA artifacts expected"* ]]
}

# ---------------------------------------------------------------------------
# T7a-6 — qa_plan: required, each missing sub-heading produces named error
#          Parameterised: iterate over each of the 4 required sub-headings.
# ---------------------------------------------------------------------------

@test "T7a-6a: qa_plan: required + '### Acceptance criteria' missing → BLOCK names that heading" {
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"
  PLAN="$TMP_DIR/missing-acceptance.md"
  make_plan_required "$PLAN" "# Missing Acceptance Criteria

## QA Plan

### Happy path (user flow)
1. Step one.

### Failure modes (what could break)
- Mode one.

### QA artifacts expected
- Stage 3 (pre-merge): full run.
- Design reference: n/a.
"
  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Acceptance criteria"* ]]
}

@test "T7a-6b: qa_plan: required + '### Happy path (user flow)' missing → BLOCK names that heading" {
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"
  PLAN="$TMP_DIR/missing-happy-path.md"
  make_plan_required "$PLAN" "# Missing Happy Path

## QA Plan

### Acceptance criteria
- Criterion one.

### Failure modes (what could break)
- Mode one.

### QA artifacts expected
- Stage 3 (pre-merge): full run.
- Design reference: n/a.
"
  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Happy path"* ]]
}

@test "T7a-6c: qa_plan: required + '### Failure modes (what could break)' missing → BLOCK names that heading" {
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"
  PLAN="$TMP_DIR/missing-failure-modes.md"
  make_plan_required "$PLAN" "# Missing Failure Modes

## QA Plan

### Acceptance criteria
- Criterion one.

### Happy path (user flow)
1. Step one.

### QA artifacts expected
- Stage 3 (pre-merge): full run.
- Design reference: n/a.
"
  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failure modes"* ]]
}

@test "T7a-6d: qa_plan: required + '### QA artifacts expected' missing → BLOCK names that heading" {
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"
  PLAN="$TMP_DIR/missing-qa-artifacts.md"
  make_plan_required "$PLAN" "# Missing QA Artifacts

## QA Plan

### Acceptance criteria
- Criterion one.

### Happy path (user flow)
1. Step one.

### Failure modes (what could break)
- Mode one.
"
  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"QA artifacts expected"* ]]
}

# ---------------------------------------------------------------------------
# T7a-7 — qa_plan: required + ## QA Plan section present but completely empty → BLOCK
# ---------------------------------------------------------------------------

@test "T7a-7: qa_plan: required + ## QA Plan section present but empty body → BLOCK" {
  # xfail: check_qa_plan_body not implemented yet (T7b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T7b implementation not yet present"

  PLAN="$TMP_DIR/required-empty-section.md"
  make_plan_required "$PLAN" "# Empty QA Section

## QA Plan

## Next section starts here

Some content.
"

  run check_qa_plan_body "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"QA Plan"* ]]
}
