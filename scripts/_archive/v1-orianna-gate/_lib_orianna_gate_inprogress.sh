#!/bin/sh
# _lib_orianna_gate_inprogress.sh — Sourceable lib: approved → in-progress gate checks.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D2.2, T4.1
#
# Provides bash functions implementing the §D2.2 approved→in-progress gate checks.
# Each function returns 0 on pass, non-zero with stderr diagnosis on failure.
#
# Functions:
#   check_tasks_section <plan_file>
#   check_estimate_minutes <plan_file>         (delegates to _lib_orianna_estimates.sh)
#   check_test_tasks_present <plan_file>
#   check_test_plan_section <plan_file>
#   check_sibling_absent <plan_file> <plans_root>
#   check_approved_carry_forward <plan_file>   (calls orianna-verify-signature.sh)
#
# Usage (sourced):
#   . scripts/_lib_orianna_gate_inprogress.sh
#   check_tasks_section path/to/plan.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" 2>/dev/null && pwd || echo ".")"

# Source the estimates lib (check_estimate_minutes)
_LIB_ESTIMATES="${SCRIPT_DIR}/_lib_orianna_estimates.sh"
if [ -f "$_LIB_ESTIMATES" ]; then
  . "$_LIB_ESTIMATES"
fi

ORIANNA_VERIFY="${SCRIPT_DIR}/orianna-verify-signature.sh"

# ---------------------------------------------------------------------------
# check_tasks_section <plan_file>
# Verifies a non-empty ## Tasks section exists inline in the plan.
# ---------------------------------------------------------------------------
check_tasks_section() {
  _cts_plan="$1"
  [ -f "$_cts_plan" ] || { printf '[gate-inprogress] ERROR: plan not found: %s\n' "$_cts_plan" >&2; return 2; }

  # Check heading exists
  if ! grep -q '^## Tasks[[:space:]]*$' "$_cts_plan" 2>/dev/null; then
    printf '[gate-inprogress] BLOCK: missing ## Tasks section; task breakdown must be inlined (§D2.2/§D3)\n' >&2
    return 1
  fi

  # Check section has at least one non-empty line
  _tasks_content="$(awk '
    /^## Tasks[[:space:]]*$/ { in_tasks=1; next }
    in_tasks && /^## / { exit }
    in_tasks { gsub(/[[:space:]]/, ""); if (length($0)>0) { print; exit } }
  ' "$_cts_plan")"

  if [ -z "$_tasks_content" ]; then
    printf '[gate-inprogress] BLOCK: ## Tasks section is empty; at least one task entry required (§D2.2)\n' >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# check_estimate_minutes <plan_file>
# Delegates to _lib_orianna_estimates.sh. Re-declared here as a no-op pass-
# through if the lib was already sourced (the source above provides it).
# ---------------------------------------------------------------------------
# (Already provided by _lib_orianna_estimates.sh if sourced above.)
# If _lib_orianna_estimates.sh is missing, provide a stub:
if ! command -v check_estimate_minutes >/dev/null 2>&1; then
  check_estimate_minutes() {
    printf '[gate-inprogress] ERROR: _lib_orianna_estimates.sh not found — cannot validate estimate_minutes\n' >&2
    return 2
  }
fi

# ---------------------------------------------------------------------------
# check_test_tasks_present <plan_file>
# Verifies at least one test task exists when tests_required is not false.
# ---------------------------------------------------------------------------
check_test_tasks_present() {
  _cttp_plan="$1"
  [ -f "$_cttp_plan" ] || { printf '[gate-inprogress] ERROR: plan not found: %s\n' "$_cttp_plan" >&2; return 2; }

  # Check tests_required in frontmatter (default true if absent)
  _tests_required="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if(dashes==2) exit; next }
    dashes==1 && /^tests_required:/ {
      sub(/^tests_required:[[:space:]]*/, "")
      gsub(/[[:space:]]/, "")
      print; exit
    }
  ' "$_cttp_plan")"

  case "$_tests_required" in
    false|'false'|'False'|'FALSE')
      return 0  # tests_required: false → skip this check
      ;;
  esac

  # Look for test task: kind: test OR title matches write/add/create/update ... test
  _tasks_section="$(awk '
    /^## Tasks[[:space:]]*$/ { in_tasks=1; next }
    in_tasks && /^## / { exit }
    in_tasks { print }
  ' "$_cttp_plan")"

  if [ -z "$_tasks_section" ]; then
    printf '[gate-inprogress] BLOCK: ## Tasks section missing — cannot check for test tasks (§D2.2)\n' >&2
    return 1
  fi

  # Check for kind: test
  if printf '%s\n' "$_tasks_section" | grep -qi 'kind:[[:space:]]*test'; then
    return 0
  fi

  # Check for title matching write/add/create/update ... test (case-insensitive)
  if printf '%s\n' "$_tasks_section" | grep -qi '^\- \[.\].*\*\*\(write\|add\|create\|update\).*test'; then
    return 0
  fi
  if printf '%s\n' "$_tasks_section" | grep -qi 'write.*test\|add.*test\|create.*test\|update.*test'; then
    return 0
  fi

  printf '[gate-inprogress] BLOCK: no test task found in ## Tasks; at least one kind: test task or task titled "write/add/create/update ... test" required when tests_required: true (§D2.2)\n' >&2
  return 1
}

# ---------------------------------------------------------------------------
# check_test_plan_section <plan_file>
# Verifies an inline ## Test plan section exists and is non-empty.
# ---------------------------------------------------------------------------
check_test_plan_section() {
  _ctps_plan="$1"
  [ -f "$_ctps_plan" ] || { printf '[gate-inprogress] ERROR: plan not found: %s\n' "$_ctps_plan" >&2; return 2; }

  # Check tests_required (default true)
  _tests_req="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if(dashes==2) exit; next }
    dashes==1 && /^tests_required:/ {
      sub(/^tests_required:[[:space:]]*/, "")
      gsub(/[[:space:]]/, "")
      print; exit
    }
  ' "$_ctps_plan")"

  case "$_tests_req" in
    false|'false'|'False'|'FALSE')
      return 0
      ;;
  esac

  # Check heading exists
  if ! grep -q '^## Test plan[[:space:]]*$' "$_ctps_plan" 2>/dev/null; then
    printf '[gate-inprogress] BLOCK: missing ## Test plan section; test plan must be inlined (§D2.2/§D3)\n' >&2
    return 1
  fi

  # Check non-empty
  _tp_content="$(awk '
    /^## Test plan[[:space:]]*$/ { in_tp=1; next }
    in_tp && /^## / { exit }
    in_tp { gsub(/[[:space:]]/, ""); if (length($0)>0) { print; exit } }
  ' "$_ctps_plan")"

  if [ -z "$_tp_content" ]; then
    printf '[gate-inprogress] BLOCK: ## Test plan section is empty; test plan content required (§D2.2)\n' >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# check_sibling_absent <plan_file> <plans_root>
# Verifies no <basename>-tasks.md or <basename>-tests.md sibling exists.
# ---------------------------------------------------------------------------
check_sibling_absent() {
  _csa_plan="$1"
  _csa_plans_root="$2"

  [ -f "$_csa_plan" ] || { printf '[gate-inprogress] ERROR: plan not found: %s\n' "$_csa_plan" >&2; return 2; }
  [ -d "$_csa_plans_root" ] || { printf '[gate-inprogress] ERROR: plans_root not found: %s\n' "$_csa_plans_root" >&2; return 2; }

  _basename="$(basename "$_csa_plan" .md)"
  _fail=0

  # Search for sibling files anywhere under plans_root
  _tasks_sibling="$(find "$_csa_plans_root" -name "${_basename}-tasks.md" 2>/dev/null | head -1)"
  _tests_sibling="$(find "$_csa_plans_root" -name "${_basename}-tests.md" 2>/dev/null | head -1)"

  if [ -n "$_tasks_sibling" ]; then
    printf '[gate-inprogress] BLOCK: sibling file "%s" must be removed; inline its content under ## Tasks (§D3)\n' "$_tasks_sibling" >&2
    _fail=1
  fi

  if [ -n "$_tests_sibling" ]; then
    printf '[gate-inprogress] BLOCK: sibling file "%s" must be removed; inline its content under ## Test plan (§D3)\n' "$_tests_sibling" >&2
    _fail=1
  fi

  return "$_fail"
}

# ---------------------------------------------------------------------------
# check_approved_carry_forward <plan_file>
# Verifies orianna_signature_approved is present and valid.
# ---------------------------------------------------------------------------
check_approved_carry_forward() {
  _cacf_plan="$1"
  [ -f "$_cacf_plan" ] || { printf '[gate-inprogress] ERROR: plan not found: %s\n' "$_cacf_plan" >&2; return 2; }

  # Check field exists in frontmatter
  _sig_field="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if(dashes==2) exit; next }
    dashes==1 && /^orianna_signature_approved:/ { print; exit }
  ' "$_cacf_plan")"

  if [ -z "$_sig_field" ]; then
    printf '[gate-inprogress] BLOCK: missing orianna_signature_approved in frontmatter; plan must have a valid approved-phase signature before in-progress signing (§D2.2). Run: scripts/orianna-sign.sh <plan> approved\n' >&2
    return 1
  fi

  # Verify signature using the verify script
  if [ ! -f "$ORIANNA_VERIFY" ]; then
    printf '[gate-inprogress] ERROR: orianna-verify-signature.sh not found at %s\n' "$ORIANNA_VERIFY" >&2
    return 2
  fi

  _verify_err="$(bash "$ORIANNA_VERIFY" "$_cacf_plan" approved 2>&1)" && _verify_rc=0 || _verify_rc=$?
  if [ "$_verify_rc" -ne 0 ]; then
    printf '[gate-inprogress] BLOCK: approved-signature invalid: %s\n' "$_verify_err" >&2
    printf '  Re-sign with: scripts/orianna-sign.sh <plan> approved (§D9.4)\n' >&2
    return 1
  fi

  return 0
}
