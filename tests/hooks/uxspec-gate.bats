#!/usr/bin/env bats
# tests/hooks/uxspec-gate.bats
#
# xfail test suite for the PreToolUse dispatch-gate hook (Rule 22 / Stream C).
#
# Plan ref: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md
# Task ref: T-C1 (xfail bats fixture)
#
# XFAIL MARKER — all tests in this file are expected to fail until Viktor
# implements `scripts/hooks/pretooluse-uxspec-gate.sh` (T-C2 through T-C4).
# The hook does not exist yet; the guard at the top of each test will emit
# an XFAIL skip rather than an execution failure, keeping the suite green
# in xfail state.
#
# xfail: pretooluse-uxspec-gate.sh absent — all cases expected to be skipped
# until Viktor's T-C2/T-C3/T-C4 commits land on this branch.
#
# Test contract (per plan §Tasks Stream C):
#   (a) Seraphine dispatch on ui-no-spec.md    → hook exits 2, stderr names Lulu/Neeko
#   (b) Seraphine dispatch on ui-with-spec.md  → hook exits 0
#   (c) Seraphine dispatch on ui-waiver.md     → hook exits 0
#   (d) Seraphine dispatch on non-ui.md        → hook exits 0
#   (e) Aphelios dispatch on ui-no-spec.md     → hook exits 0 (only seraphine/soraka gated)
#
# Additional edge cases:
#   (f) Soraka dispatch on ui-no-spec.md       → hook exits 2 (soraka also gated)
#   (g) §UX Spec heading present but body empty → hook exits 2 (empty heading-only fails)
#   (h) 'ux-waiver:' lowercase in frontmatter  → hook exits 0 (case-insensitive waiver key)
#   (i) Viktor (non-seraphine/non-soraka) dispatch on ui-no-spec.md → hook exits 0
#
# bats test_tags=tag:uxspec-gate,tag:rule-22,tag:stream-c

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/scripts/hooks/pretooluse-uxspec-gate.sh"
FIXTURES="$REPO_ROOT/tests/fixtures/uxspec-gate"

# ---------------------------------------------------------------------------
# Helper: build a minimal PreToolUse Agent dispatch payload.
#   $1 = subagent_type
#   $2 = plan description (a short string that embeds the plan path)
# ---------------------------------------------------------------------------
make_payload() {
  local subagent="$1"
  local description="$2"
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":"%s","description":"%s"}}' \
    "$subagent" "$description"
}

# ---------------------------------------------------------------------------
# Guard: skip all tests with an XFAIL message when hook is absent.
# This is the xfail state — tests exit 0 (bats skip) until Viktor's impl lands.
# ---------------------------------------------------------------------------
hook_absent_guard() {
  if [ ! -f "$HOOK" ]; then
    skip "XFAIL: pretooluse-uxspec-gate.sh absent — xfail per plan 2026-04-25-frontend-uiux-in-process.md T-C1"
  fi
}

# ---------------------------------------------------------------------------
# (a) Seraphine dispatch on UI plan missing §UX Spec — must be blocked (exit 2)
# ---------------------------------------------------------------------------
@test "(a) seraphine + ui-no-spec: hook blocks dispatch (exit 2)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local plan_path="$FIXTURES/ui-no-spec.md"
  local payload
  payload="$(make_payload "seraphine" "Implement button component per $plan_path")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  [ "$status" -eq 2 ]
  # stderr must name Lulu or Neeko as next step
  [[ "$output" == *"lulu"* ]] || [[ "$output" == *"neeko"* ]] || \
  [[ "$stderr" == *"lulu"* ]] || [[ "$stderr" == *"neeko"* ]]
}

# ---------------------------------------------------------------------------
# (b) Seraphine dispatch on UI plan WITH valid §UX Spec — must pass (exit 0)
# ---------------------------------------------------------------------------
@test "(b) seraphine + ui-with-spec: hook allows dispatch (exit 0)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local plan_path="$FIXTURES/ui-with-spec.md"
  local payload
  payload="$(make_payload "seraphine" "Implement button component per $plan_path")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (c) Seraphine dispatch on UI plan with UX-Waiver frontmatter — must pass (exit 0)
# ---------------------------------------------------------------------------
@test "(c) seraphine + ui-waiver: UX-Waiver frontmatter allows dispatch (exit 0)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local plan_path="$FIXTURES/ui-waiver.md"
  local payload
  payload="$(make_payload "seraphine" "Refactor button per $plan_path")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (d) Seraphine dispatch on non-UI plan — must pass (exit 0, path-glob no-match)
# ---------------------------------------------------------------------------
@test "(d) seraphine + non-ui: path-glob no-match, hook allows dispatch (exit 0)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local plan_path="$FIXTURES/non-ui.md"
  local payload
  payload="$(make_payload "seraphine" "Implement API endpoint per $plan_path")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (e) Aphelios dispatch on UI plan missing §UX Spec — must pass (exit 0)
# Hook is scoped to seraphine/soraka only; other agents are never gated.
# ---------------------------------------------------------------------------
@test "(e) aphelios + ui-no-spec: non-gated agent bypasses hook (exit 0)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local plan_path="$FIXTURES/ui-no-spec.md"
  local payload
  payload="$(make_payload "aphelios" "Break down tasks per $plan_path")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (f) Soraka dispatch on UI plan missing §UX Spec — must be blocked (exit 2)
# Soraka is in the gated set alongside Seraphine.
# ---------------------------------------------------------------------------
@test "(f) soraka + ui-no-spec: hook blocks dispatch (exit 2)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local plan_path="$FIXTURES/ui-no-spec.md"
  local payload
  payload="$(make_payload "soraka" "Implement trivial button tweak per $plan_path")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# (g) §UX Spec heading present but body is empty — must block (exit 2)
# An empty heading-only §UX Spec does not satisfy the gate requirement.
# ---------------------------------------------------------------------------
@test "(g) seraphine + ux-spec-empty-heading: empty §UX Spec body blocks dispatch (exit 2)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  # Create an ephemeral fixture with an empty §UX Spec
  local tmp_plan
  tmp_plan="$(mktemp /tmp/uxspec-gate-empty-spec.XXXXXX.md)"
  cat > "$tmp_plan" <<'PLAN'
---
status: approved
concern: personal
owner: seraphine
created: 2026-04-25
complexity: standard
---

# Test: UI plan with empty §UX Spec heading

## Decision

Add component.

## UX Spec

## Tasks

- [ ] T-1 — implement `apps/frontend/src/components/Card.vue`. estimate_minutes: 20.
PLAN

  local payload
  payload="$(make_payload "seraphine" "Implement card per $tmp_plan")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  rm -f "$tmp_plan"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# (h) 'ux-waiver:' lowercase in frontmatter — must pass (case-insensitive key)
# The hook must accept both 'UX-Waiver:' and 'ux-waiver:' in frontmatter.
# ---------------------------------------------------------------------------
@test "(h) seraphine + lowercase ux-waiver: case-insensitive waiver key allows dispatch (exit 0)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local tmp_plan
  tmp_plan="$(mktemp /tmp/uxspec-gate-lc-waiver.XXXXXX.md)"
  cat > "$tmp_plan" <<'PLAN'
---
status: approved
concern: personal
owner: seraphine
created: 2026-04-25
complexity: standard
ux-waiver: pure refactor — no visible delta
---

# Test: UI plan with lowercase ux-waiver key

## Decision

Refactor component.

## Tasks

- [ ] T-1 — refactor `apps/frontend/src/components/Card.vue`. estimate_minutes: 15.
PLAN

  local payload
  payload="$(make_payload "seraphine" "Refactor card per $tmp_plan")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  rm -f "$tmp_plan"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (i) Non-seraphine, non-soraka agent (viktor) on UI plan missing §UX Spec — exit 0
# Gate is strictly scoped to seraphine and soraka per D2.
# ---------------------------------------------------------------------------
@test "(i) viktor + ui-no-spec: nonsense/non-gated subagent_type bypasses hook (exit 0)" {
  # xfail: hook absent — skip until T-C2/T-C3/T-C4 impl lands
  hook_absent_guard

  local plan_path="$FIXTURES/ui-no-spec.md"
  local payload
  payload="$(make_payload "viktor" "Implement button component per $plan_path")"

  run bash -c "printf '%s' '$payload' | REPO_ROOT='$REPO_ROOT' bash '$HOOK'"
  [ "$status" -eq 0 ]
}
