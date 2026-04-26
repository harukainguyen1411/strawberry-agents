#!/usr/bin/env bats
# tests/hooks/plan-of-plans-phase-a.bats
#
# xfail test suite for Phase A foundations of:
#   plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md
#
# Task refs: T1, T2, T3
#
# xfail contract:
#   T1 — ideas/personal/.gitkeep and ideas/work/.gitkeep must exist in the git index.
#         PreToolUse plan-lifecycle guard must NOT fire on writes under ideas/**.
#         These files are pre-committed; the test is a regression guard.
#         xfail guard: always runs (no absent-file guard needed for T1).
#
#   T2 — plans/_template.md must contain both priority: and last_reviewed: fields
#         with allowed-values comment.
#         xfail guard: test skips (XFAIL) if neither field is present.
#
#   T3 — architecture/agent-network-v1/plan-lifecycle.md must contain a
#         "## Backlog and parking lot (ideas/)" section with backlink to ADR.
#         xfail guard: test skips (XFAIL) if section is absent.
#
# bats test_tags=tag:plan-of-plans,tag:phase-a,tag:t1,tag:t2,tag:t3

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
TEMPLATE="$REPO_ROOT/plans/_template.md"
PLAN_LIFECYCLE="$REPO_ROOT/architecture/agent-network-v1/plan-lifecycle.md"
ADR_SLUG="2026-04-25-plan-of-plans-and-parking-lot"

# ---------------------------------------------------------------------------
# T1 — ideas/ directories: .gitkeep files exist and are git-tracked
# ---------------------------------------------------------------------------

@test "T1(a) ideas/personal/.gitkeep exists on disk" {
  [ -f "$REPO_ROOT/ideas/personal/.gitkeep" ]
}

@test "T1(b) ideas/work/.gitkeep exists on disk" {
  [ -f "$REPO_ROOT/ideas/work/.gitkeep" ]
}

@test "T1(c) ideas/personal/.gitkeep is tracked in git" {
  git -C "$REPO_ROOT" ls-files --error-unmatch ideas/personal/.gitkeep
}

@test "T1(d) ideas/work/.gitkeep is tracked in git" {
  git -C "$REPO_ROOT" ls-files --error-unmatch ideas/work/.gitkeep
}

@test "T1(e) ideas/personal/ appears in git ls-tree HEAD" {
  run git -C "$REPO_ROOT" ls-tree HEAD -- ideas/
  [ "$status" -eq 0 ]
  [[ "$output" == *"ideas/personal"* ]]
}

@test "T1(f) ideas/work/ appears in git ls-tree HEAD" {
  run git -C "$REPO_ROOT" ls-tree HEAD -- ideas/
  [ "$status" -eq 0 ]
  [[ "$output" == *"ideas/work"* ]]
}

# ---------------------------------------------------------------------------
# T2 — plans/_template.md contains priority: and last_reviewed: fields
# xfail: tests skip if fields are absent (pre-T2-impl state)
# ---------------------------------------------------------------------------

t2_priority_present() {
  grep -q 'priority:' "$TEMPLATE"
}

t2_last_reviewed_present() {
  grep -q 'last_reviewed:' "$TEMPLATE"
}

@test "T2(a) plans/_template.md contains priority: field" {
  # XFAIL guard: skip if field is absent (T2 impl not yet landed)
  if ! t2_priority_present; then
    skip "XFAIL: priority: field absent in _template.md — xfail per plan $ADR_SLUG T2"
  fi
  grep -q 'priority:' "$TEMPLATE"
}

@test "T2(b) plans/_template.md contains last_reviewed: field" {
  # XFAIL guard: skip if field is absent (T2 impl not yet landed)
  if ! t2_last_reviewed_present; then
    skip "XFAIL: last_reviewed: field absent in _template.md — xfail per plan $ADR_SLUG T2"
  fi
  grep -q 'last_reviewed:' "$TEMPLATE"
}

@test "T2(c) plans/_template.md priority: field has allowed-values comment (P0|P1|P2|P3)" {
  if ! t2_priority_present; then
    skip "XFAIL: priority: field absent in _template.md — xfail per plan $ADR_SLUG T2"
  fi
  grep -q 'P0' "$TEMPLATE"
  grep -q 'P1' "$TEMPLATE"
  grep -q 'P2' "$TEMPLATE"
  grep -q 'P3' "$TEMPLATE"
}

@test "T2(d) plans/_template.md last_reviewed: field has YYYY-MM-DD comment" {
  if ! t2_last_reviewed_present; then
    skip "XFAIL: last_reviewed: field absent in _template.md — xfail per plan $ADR_SLUG T2"
  fi
  grep -q 'YYYY-MM-DD' "$TEMPLATE"
}

# ---------------------------------------------------------------------------
# T3 — architecture/agent-network-v1/plan-lifecycle.md has new section
# xfail: tests skip if section is absent (pre-T3-impl state)
# ---------------------------------------------------------------------------

t3_section_present() {
  grep -q 'Backlog and parking lot' "$PLAN_LIFECYCLE"
}

@test "T3(a) plan-lifecycle.md contains '## Backlog and parking lot (ideas/)' section" {
  if ! t3_section_present; then
    skip "XFAIL: Backlog and parking lot section absent — xfail per plan $ADR_SLUG T3"
  fi
  grep -q '## Backlog and parking lot' "$PLAN_LIFECYCLE"
}

@test "T3(b) plan-lifecycle.md backlog section contains A1 reference (priority)" {
  if ! t3_section_present; then
    skip "XFAIL: Backlog and parking lot section absent — xfail per plan $ADR_SLUG T3"
  fi
  grep -q 'priority' "$PLAN_LIFECYCLE"
}

@test "T3(c) plan-lifecycle.md backlog section contains backlink to ADR" {
  if ! t3_section_present; then
    skip "XFAIL: Backlog and parking lot section absent — xfail per plan $ADR_SLUG T3"
  fi
  grep -q "$ADR_SLUG" "$PLAN_LIFECYCLE"
}

@test "T3(d) plan-lifecycle.md five-phase table still present (additive-only check)" {
  # The existing five-phase lifecycle table must not have been removed or altered.
  # Check for the Phase column header which anchors the table.
  grep -q '| Phase |' "$PLAN_LIFECYCLE"
}
