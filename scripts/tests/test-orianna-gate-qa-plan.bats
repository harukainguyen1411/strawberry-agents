#!/usr/bin/env bats
# scripts/tests/test-orianna-gate-qa-plan.bats
#
# T6a — xfail tests: Orianna gate v2 qa_plan frontmatter field enforcement.
#
# Plan: plans/approved/personal/2026-04-25-structured-qa-pipeline.md §T6a
# Test plan items: Test 1 (frontmatter field missing → REJECT with named error)
#                  Frontmatter value coverage: inline / none / required / missing
#
# xfail: all assertions are expected to fail until T6b lands the implementation in
#        scripts/hooks/pre-commit-zz-plan-structure.sh and .claude/agents/orianna.md.
#        The guard function check_qa_plan_frontmatter does not yet exist.
#
# Run: bats scripts/tests/test-orianna-gate-qa-plan.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/_lib_plan_structure.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# make_plan_file <path> <frontmatter_extra_lines> <body>
# Creates a minimal but structurally valid plan file.
# $1 — absolute path to write
# $2 — extra YAML lines to append into the frontmatter block (newline-separated)
# $3 — markdown body (everything after the closing ---)
make_plan_file() {
  _path="$1"
  _fm_extra="$2"
  _body="$3"
  cat > "$_path" <<PLAN_EOF
---
status: proposed
concern: personal
owner: test-author
created: 2026-04-25
tests_required: true
${_fm_extra}
---

${_body}
PLAN_EOF
}

QA_PLAN_BODY_FULL='## QA Plan

### Acceptance criteria
- System rejects a plan whose qa_plan field is absent.
- System accepts a plan whose qa_plan field is one of: required, inline, none.

### Happy path (user flow)
1. Author creates plan with qa_plan: required.
2. Author adds ## QA Plan section with all four sub-headings.
3. Orianna promotes the plan to approved.

### Failure modes (what could break)
- qa_plan field missing: trigger → REJECT with "qa_plan field missing" error.
- qa_plan value invalid: trigger → REJECT with "invalid qa_plan value" error.

### QA artifacts expected
- Stage 2 (draft-PR smoke): screenshot on the plan-list view showing the new field.
- Stage 3 (pre-merge): full Playwright run against plan-detail route.
- Design reference: n/a — backend surface.
'

QA_PLAN_BODY_INLINE='## QA Plan

Trivial typo fix — no acceptance criteria matrix needed.
'

# ---------------------------------------------------------------------------
# xfail guard: implementation not yet present
# ---------------------------------------------------------------------------

setup() {
  TMP_DIR="$(mktemp -d)"
  # Determine whether the implementation is present.
  # T6b adds check_qa_plan_frontmatter to _lib_plan_structure.sh.
  IMPL_PRESENT=0
  if grep -q 'check_qa_plan_frontmatter' "$LIB" 2>/dev/null; then
    IMPL_PRESENT=1
    # Source the lib so we can call the function directly.
    # shellcheck source=/dev/null
    . "$LIB"
  fi
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# T6a-1 — qa_plan: inline passes body validation when ## QA Plan section present
# ---------------------------------------------------------------------------

@test "T6a-1: qa_plan: inline + ## QA Plan section present → passes (no BLOCK)" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/inline-with-section.md"
  make_plan_file "$PLAN" \
    "qa_plan: inline
qa_co_author: lulu" \
    "# Inline QA Plan Test

${QA_PLAN_BODY_INLINE}"

  run check_qa_plan_frontmatter "$PLAN"
  [ "$status" -eq 0 ]
  # No BLOCK: error message
  echo "$output" | grep -qv '\[lib-plan-structure\] BLOCK:'
}

# ---------------------------------------------------------------------------
# T6a-2 — qa_plan: none + justification line → skips body section check
# ---------------------------------------------------------------------------

@test "T6a-2: qa_plan: none + justification present → passes (body section optional)" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/none-with-justification.md"
  make_plan_file "$PLAN" \
    "qa_plan: none
qa_plan_none_justification: Pure agent-def edit, no user-observable surface." \
    "# No QA Surface Test

This plan modifies only agent definitions — no user-observable surface.
"

  run check_qa_plan_frontmatter "$PLAN"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T6a-3 — qa_plan: none without justification → BLOCK
# ---------------------------------------------------------------------------

@test "T6a-3: qa_plan: none without justification → BLOCK naming missing justification" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/none-no-justification.md"
  make_plan_file "$PLAN" \
    "qa_plan: none" \
    "# No Justification Test

Agent-def edit — justification field omitted.
"

  run check_qa_plan_frontmatter "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  # Error must name the missing justification field
  [[ "$output" == *"qa_plan_none_justification"* ]] || [[ "$output" == *"justification"* ]]
}

# ---------------------------------------------------------------------------
# T6a-4 — qa_plan: required + all four sub-headings + qa_co_author → passes
# ---------------------------------------------------------------------------

@test "T6a-4: qa_plan: required + ## QA Plan with all 4 sub-headings + qa_co_author → passes" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/required-complete.md"
  make_plan_file "$PLAN" \
    "qa_plan: required
qa_co_author: lulu" \
    "# Required QA Plan Test

${QA_PLAN_BODY_FULL}"

  run check_qa_plan_frontmatter "$PLAN"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T6a-5 — missing qa_plan frontmatter → BLOCK citing "qa_plan field missing"
# ---------------------------------------------------------------------------

@test "T6a-5: missing qa_plan frontmatter → BLOCK with 'qa_plan field missing' error string" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  # This is the primary Test 1 assertion from the plan's §Test plan.
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/missing-qa-plan-field.md"
  # No qa_plan field in frontmatter at all
  make_plan_file "$PLAN" \
    "" \
    "# Missing Field Test

Some body content. No qa_plan field declared in frontmatter.
"

  run check_qa_plan_frontmatter "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  # Error string must match the documented error: "qa_plan field missing"
  [[ "$output" == *"qa_plan field missing"* ]]
}

# ---------------------------------------------------------------------------
# T6a-6 — qa_plan invalid value → BLOCK citing invalid value
# ---------------------------------------------------------------------------

@test "T6a-6: qa_plan value not in {required|inline|none} → BLOCK with invalid value error" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/invalid-value.md"
  make_plan_file "$PLAN" \
    "qa_plan: maybe" \
    "# Invalid Value Test

Body content here.
"

  run check_qa_plan_frontmatter "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid qa_plan value"* ]] || [[ "$output" == *"qa_plan"* ]]
}

# ---------------------------------------------------------------------------
# T6a-7 — qa_plan: required without qa_co_author → BLOCK citing missing co-author
# ---------------------------------------------------------------------------

@test "T6a-7: qa_plan: required without qa_co_author → BLOCK naming missing qa_co_author" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/required-no-coauthor.md"
  make_plan_file "$PLAN" \
    "qa_plan: required" \
    "# No Co-author Test

${QA_PLAN_BODY_FULL}"

  run check_qa_plan_frontmatter "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"qa_co_author"* ]]
}

# ---------------------------------------------------------------------------
# T6a-8 — I2 regression: quoted YAML value "required" must be accepted
# ---------------------------------------------------------------------------

@test "T6a-8: qa_plan: \"required\" (quoted YAML value) + qa_co_author: senna → passes (I2 regression)" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  # Covers I2: YAML allows quoted values; the linter must strip quotes before matching.
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/quoted-required.md"
  # Write frontmatter manually to embed a quoted qa_plan value
  cat > "$PLAN" <<'PLAN_EOF'
---
status: proposed
concern: personal
owner: test-author
created: 2026-04-25
tests_required: true
qa_plan: "required"
qa_co_author: senna
---

# Quoted Value Frontmatter Test

Some body content.
PLAN_EOF

  run check_qa_plan_frontmatter "$PLAN"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T6a-9 — I4 regression: invalid qa_co_author value is rejected
# ---------------------------------------------------------------------------

@test "T6a-9: qa_plan: required + qa_co_author: nobody → BLOCK naming invalid co-author (I4 regression)" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  # Covers I4: qa_co_author whitelist enforcement — only lulu and senna are valid.
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/invalid-coauthor.md"
  make_plan_file "$PLAN" \
    "qa_plan: required
qa_co_author: nobody" \
    "# Invalid Co-author Test

${QA_PLAN_BODY_FULL}"

  run check_qa_plan_frontmatter "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"qa_co_author"* ]]
}

# ---------------------------------------------------------------------------
# T6a-10 — I3 regression: trivially short justification is rejected
# ---------------------------------------------------------------------------

@test "T6a-10: qa_plan: none + single-char justification → BLOCK (I3 regression)" {
  # xfail: check_qa_plan_frontmatter not implemented yet (T6b)
  # Covers I3: minimum 10-character justification requirement.
  [ "$IMPL_PRESENT" -eq 1 ] || skip "xfail — T6b implementation not yet present"

  PLAN="$TMP_DIR/trivial-justification.md"
  make_plan_file "$PLAN" \
    "qa_plan: none
qa_plan_none_justification: ." \
    "# Trivial Justification Test

Some body content.
"

  run check_qa_plan_frontmatter "$PLAN" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"qa_plan_none_justification"* ]] || [[ "$output" == *"justification"* ]]
}
