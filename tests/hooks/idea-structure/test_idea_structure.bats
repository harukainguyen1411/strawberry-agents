#!/usr/bin/env bats
# tests/hooks/idea-structure/test_idea_structure.bats
#
# xfail test suite for the new pre-commit-zz-idea-structure.sh hook.
# Plan ref: plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md
# Task ref: T5 (xfail fixtures + tests), T7 (implementation)
#
# XFAIL MARKER — all tests in this file are expected to fail (skip) until T7 implements
# scripts/hooks/pre-commit-zz-idea-structure.sh. The hook_absent_guard() emits an XFAIL
# skip rather than a hard failure, keeping the suite green in the pre-impl state.
#
# xfail: pre-commit-zz-idea-structure.sh absent — all cases expected to skip
# until T7 impl lands.
#
# Test contract (per plan §Tasks T5/T7):
#   (a) idea-with-tasks-header.md (## Tasks) → hook rejects with "this is a plan, not an idea"
#   (b) idea-with-test-plan-header (## Test plan) → hook rejects with canonical message
#   (c) idea-with-design-header (## Design) → hook rejects with canonical message
#   (d) idea-with-decision-header (## Decision) → hook rejects with canonical message
#   (e) idea-with-risks-header (## Risks) → hook rejects with canonical message
#   (f) idea-with-rollback-header (## Rollback) → hook rejects with canonical message
#   (g) idea-with-open-questions-header (## Open questions) → hook rejects with canonical message
#   (h) idea-missing-frontmatter-field.md (missing last_reviewed) → hook rejects
#   (i) idea-bad-concern-value.md (concern: team) → hook rejects
#   (j) idea-valid.md → hook accepts (exit 0)
#   (k) non-ideas path → hook skips (exit 0); only ideas/** is gated
#   (l) hook passes bash -n syntax check
#
# bats test_tags=tag:plan-of-plans,tag:phase-b,tag:t5,tag:t7,tag:idea-structure

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-zz-idea-structure.sh"
FIXTURES="$REPO_ROOT/tests/hooks/idea-structure/fixtures"

# Canonical error message from ADR §A2 — must appear verbatim in hook output.
CANONICAL_ERROR="this is a plan, not an idea"

# Force error mode in tests regardless of sunset date.
# Tests verify validation logic; sunset behavior is separately verified in T9/T18.
export STRAWBERRY_IDEA_LINT_LEVEL=error

# ---------------------------------------------------------------------------
# Guard: skip all tests with an XFAIL message when hook is absent.
# ---------------------------------------------------------------------------
hook_absent_guard() {
  if [ ! -f "$HOOK" ]; then
    skip "XFAIL: pre-commit-zz-idea-structure.sh absent — xfail per plan 2026-04-25-plan-of-plans-and-parking-lot.md T5 (impl: T7)"
  fi
}

# ---------------------------------------------------------------------------
# Helper: run hook against a fixture, simulating it staged under ideas/<concern>/
# ---------------------------------------------------------------------------
run_hook_on_fixture() {
  local fixture_path="$1"
  local staged_path="$2"
  run bash "$HOOK" \
    --fixture-path "$fixture_path" \
    --staged-path "$staged_path"
}

# ---------------------------------------------------------------------------
# (l) Syntax check first
# ---------------------------------------------------------------------------
@test "(l) hook passes bash -n syntax check" {
  hook_absent_guard
  run bash -n "$HOOK"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (a) ## Tasks forbidden header → rejected with canonical error message
# ---------------------------------------------------------------------------
@test "(a) idea-with-tasks-header: hook rejects, output contains canonical error" {
  hook_absent_guard

  run_hook_on_fixture \
    "$FIXTURES/idea-with-tasks-header.md" \
    "ideas/personal/idea-with-tasks-header.md"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$CANONICAL_ERROR"* ]] || [[ "$stderr" == *"$CANONICAL_ERROR"* ]]
}

# ---------------------------------------------------------------------------
# (b) ## Test plan forbidden header → rejected
# ---------------------------------------------------------------------------
@test "(b) idea-with-test-plan-header: hook rejects with canonical error" {
  hook_absent_guard

  local tmp_idea
  tmp_idea="$(mktemp /tmp/idea-test-plan.XXXXXX.md)"
  cat > "$tmp_idea" <<'IDEA'
---
title: Idea with test plan header
concern: personal
created: 2026-04-26
last_reviewed: 2026-04-26
tags: [test]
---

Some idea text.

## Test plan

- Run all tests
IDEA

  run bash "$HOOK" \
    --fixture-path "$tmp_idea" \
    --staged-path "ideas/personal/idea-test-plan.md"
  rm -f "$tmp_idea"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$CANONICAL_ERROR"* ]] || [[ "$stderr" == *"$CANONICAL_ERROR"* ]]
}

# ---------------------------------------------------------------------------
# (c) ## Design forbidden header → rejected
# ---------------------------------------------------------------------------
@test "(c) idea-with-design-header: hook rejects with canonical error" {
  hook_absent_guard

  local tmp_idea
  tmp_idea="$(mktemp /tmp/idea-design.XXXXXX.md)"
  cat > "$tmp_idea" <<'IDEA'
---
title: Idea with design header
concern: personal
created: 2026-04-26
last_reviewed: 2026-04-26
tags: [test]
---

Some idea text.

## Design

Architectural description here.
IDEA

  run bash "$HOOK" \
    --fixture-path "$tmp_idea" \
    --staged-path "ideas/personal/idea-design.md"
  rm -f "$tmp_idea"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$CANONICAL_ERROR"* ]] || [[ "$stderr" == *"$CANONICAL_ERROR"* ]]
}

# ---------------------------------------------------------------------------
# (d) ## Decision forbidden header → rejected
# ---------------------------------------------------------------------------
@test "(d) idea-with-decision-header: hook rejects with canonical error" {
  hook_absent_guard

  local tmp_idea
  tmp_idea="$(mktemp /tmp/idea-decision.XXXXXX.md)"
  cat > "$tmp_idea" <<'IDEA'
---
title: Idea with decision header
concern: personal
created: 2026-04-26
last_reviewed: 2026-04-26
tags: [test]
---

Some idea text.

## Decision

We decided to do X.
IDEA

  run bash "$HOOK" \
    --fixture-path "$tmp_idea" \
    --staged-path "ideas/personal/idea-decision.md"
  rm -f "$tmp_idea"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$CANONICAL_ERROR"* ]] || [[ "$stderr" == *"$CANONICAL_ERROR"* ]]
}

# ---------------------------------------------------------------------------
# (e) ## Risks forbidden header → rejected
# ---------------------------------------------------------------------------
@test "(e) idea-with-risks-header: hook rejects with canonical error" {
  hook_absent_guard

  local tmp_idea
  tmp_idea="$(mktemp /tmp/idea-risks.XXXXXX.md)"
  cat > "$tmp_idea" <<'IDEA'
---
title: Idea with risks header
concern: personal
created: 2026-04-26
last_reviewed: 2026-04-26
tags: [test]
---

Some idea text.

## Risks

There might be some risks.
IDEA

  run bash "$HOOK" \
    --fixture-path "$tmp_idea" \
    --staged-path "ideas/personal/idea-risks.md"
  rm -f "$tmp_idea"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$CANONICAL_ERROR"* ]] || [[ "$stderr" == *"$CANONICAL_ERROR"* ]]
}

# ---------------------------------------------------------------------------
# (f) ## Rollback forbidden header → rejected
# ---------------------------------------------------------------------------
@test "(f) idea-with-rollback-header: hook rejects with canonical error" {
  hook_absent_guard

  local tmp_idea
  tmp_idea="$(mktemp /tmp/idea-rollback.XXXXXX.md)"
  cat > "$tmp_idea" <<'IDEA'
---
title: Idea with rollback header
concern: personal
created: 2026-04-26
last_reviewed: 2026-04-26
tags: [test]
---

Some idea text.

## Rollback

Revert by doing X.
IDEA

  run bash "$HOOK" \
    --fixture-path "$tmp_idea" \
    --staged-path "ideas/personal/idea-rollback.md"
  rm -f "$tmp_idea"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$CANONICAL_ERROR"* ]] || [[ "$stderr" == *"$CANONICAL_ERROR"* ]]
}

# ---------------------------------------------------------------------------
# (g) ## Open questions forbidden header → rejected
# ---------------------------------------------------------------------------
@test "(g) idea-with-open-questions-header: hook rejects with canonical error" {
  hook_absent_guard

  local tmp_idea
  tmp_idea="$(mktemp /tmp/idea-oqs.XXXXXX.md)"
  cat > "$tmp_idea" <<'IDEA'
---
title: Idea with open questions header
concern: personal
created: 2026-04-26
last_reviewed: 2026-04-26
tags: [test]
---

Some idea text.

## Open questions

- OQ1 — something unclear
IDEA

  run bash "$HOOK" \
    --fixture-path "$tmp_idea" \
    --staged-path "ideas/personal/idea-oqs.md"
  rm -f "$tmp_idea"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$CANONICAL_ERROR"* ]] || [[ "$stderr" == *"$CANONICAL_ERROR"* ]]
}

# ---------------------------------------------------------------------------
# (h) Missing required frontmatter field → rejected
# ---------------------------------------------------------------------------
@test "(h) idea-missing-frontmatter-field: hook rejects missing last_reviewed" {
  hook_absent_guard

  run_hook_on_fixture \
    "$FIXTURES/idea-missing-frontmatter-field.md" \
    "ideas/personal/idea-missing-frontmatter-field.md"

  [ "$status" -ne 0 ]
  [[ "$output" == *"last_reviewed"* ]] || [[ "$stderr" == *"last_reviewed"* ]]
}

# ---------------------------------------------------------------------------
# (i) Bad concern value → rejected
# ---------------------------------------------------------------------------
@test "(i) idea-bad-concern-value: hook rejects invalid concern (not personal|work)" {
  hook_absent_guard

  run_hook_on_fixture \
    "$FIXTURES/idea-bad-concern-value.md" \
    "ideas/personal/idea-bad-concern-value.md"

  [ "$status" -ne 0 ]
  [[ "$output" == *"concern"* ]] || [[ "$stderr" == *"concern"* ]]
}

# ---------------------------------------------------------------------------
# (j) Valid idea → accepted (exit 0)
# ---------------------------------------------------------------------------
@test "(j) idea-valid: hook accepts (exit 0)" {
  hook_absent_guard

  run_hook_on_fixture \
    "$FIXTURES/idea-valid.md" \
    "ideas/personal/idea-valid.md"

  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (k) Non-ideas path → hook skips (exit 0)
# Hook only gates files staged under ideas/**
# ---------------------------------------------------------------------------
@test "(k) non-ideas staged path: hook skips, exits 0" {
  hook_absent_guard

  # Use the bad fixture but stage it outside ideas/ — must pass.
  run_hook_on_fixture \
    "$FIXTURES/idea-with-tasks-header.md" \
    "plans/proposed/personal/some-plan.md"

  [ "$status" -eq 0 ]
}
