#!/bin/sh
# _lib_orianna_gate_implemented.sh — Sourceable lib: in-progress → implemented gate checks.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D2.3, T4.2
#
# Provides bash functions implementing the §D2.3 in-progress→implemented gate checks.
# Each function returns 0 on pass, non-zero with stderr diagnosis on failure.
#
# Functions:
#   check_claim_anchors_current <plan_file> <repo_root>
#   check_architecture_declaration <plan_file> <repo_root> [<approved_ts>]
#                                              (delegates to _lib_orianna_architecture.sh)
#   check_test_results_section <plan_file>
#   check_carry_forward_approved <plan_file>
#   check_carry_forward_inprogress <plan_file>
#
# Usage (sourced):
#   . scripts/_lib_orianna_gate_implemented.sh
#   check_test_results_section path/to/plan.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" 2>/dev/null && pwd || echo ".")"

# Source the architecture lib (check_architecture_declaration)
_LIB_ARCH="${SCRIPT_DIR}/_lib_orianna_architecture.sh"
if [ -f "$_LIB_ARCH" ]; then
  . "$_LIB_ARCH"
fi

ORIANNA_VERIFY="${SCRIPT_DIR}/orianna-verify-signature.sh"

# ---------------------------------------------------------------------------
# check_claim_anchors_current <plan_file> <repo_root>
# Re-runs path-anchor checks on the current tree (§D2.3 implementation evidence).
# Verifies each backtick path-shaped token resolves via 'test -e' in the repo.
# ---------------------------------------------------------------------------
check_claim_anchors_current() {
  _ccac_plan="$1"
  _ccac_repo="${2:-$(git rev-parse --show-toplevel 2>/dev/null)}"

  [ -f "$_ccac_plan" ] || { printf '[gate-implemented] ERROR: plan not found: %s\n' "$_ccac_plan" >&2; return 2; }
  [ -d "$_ccac_repo" ] || { printf '[gate-implemented] ERROR: repo_root not a directory: %s\n' "$_ccac_repo" >&2; return 2; }

  _ccac_fail=0

  # Extract backtick spans that look like paths (contain / or end in known extension)
  # Restrict to claim-contract §5 prefixes:
  #   agents/ plans/ scripts/ architecture/ assessments/ .claude/ tools/
  # Exclude the strawberry-app paths (apps/ dashboards/ .github/) — those require
  # a separate checkout, which may not be present; we emit warn not block for them.
  _paths="$(grep -o '\`[^`]*\`' "$_ccac_plan" 2>/dev/null | tr -d '`' | grep '/' | \
    grep -E '^(agents|plans|scripts|architecture|assessments|\.claude|tools)/' || true)"

  if [ -z "$_paths" ]; then
    return 0  # no local-repo paths to check
  fi

  printf '%s\n' "$_paths" | while IFS= read -r _path; do
    [ -n "$_path" ] || continue
    # Skip suppressed lines: grep for <!-- orianna: ok --> on the same line
    # (simplified: skip if orianna:ok appears near this path in the plan)
    if grep -q "$(printf '%s' "$_path" | sed 's/[.[\*^$]/\\&/g').*orianna: ok\|orianna: ok.*$(printf '%s' "$_path" | sed 's/[.[\*^$]/\\&/g')" "$_ccac_plan" 2>/dev/null; then
      continue
    fi

    if [ ! -e "$_ccac_repo/$_path" ]; then
      printf '[gate-implemented] BLOCK: claim "%s" not found on current tree; plan claims this path exists but it was not created during implementation (§D2.3)\n' "$_path" >&2
      exit 1
    fi
  done || _ccac_fail=1

  return "$_ccac_fail"
}

# ---------------------------------------------------------------------------
# check_architecture_declaration <plan_file> <repo_root> [<approved_ts>]
# Delegates to _lib_orianna_architecture.sh.
# If _lib_orianna_architecture.sh is missing, provide a stub.
# ---------------------------------------------------------------------------
if ! command -v check_architecture_declaration >/dev/null 2>&1; then
  check_architecture_declaration() {
    printf '[gate-implemented] ERROR: _lib_orianna_architecture.sh not found — cannot validate architecture declaration\n' >&2
    return 2
  }
fi

# ---------------------------------------------------------------------------
# check_test_results_section <plan_file>
# Verifies ## Test results section exists with at least one CI URL or assessments/ path.
# ---------------------------------------------------------------------------
check_test_results_section() {
  _ctrs_plan="$1"
  [ -f "$_ctrs_plan" ] || { printf '[gate-implemented] ERROR: plan not found: %s\n' "$_ctrs_plan" >&2; return 2; }

  # Check tests_required (default true)
  _tests_req="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if(dashes==2) exit; next }
    dashes==1 && /^tests_required:/ {
      sub(/^tests_required:[[:space:]]*/, "")
      gsub(/[[:space:]]/, "")
      print; exit
    }
  ' "$_ctrs_plan")"

  case "$_tests_req" in
    false|'false'|'False'|'FALSE')
      return 0  # tests_required: false → skip
      ;;
  esac

  # Check heading exists
  if ! grep -q '^## Test results[[:space:]]*$' "$_ctrs_plan" 2>/dev/null; then
    printf '[gate-implemented] BLOCK: missing ## Test results section; required when tests_required: true (§D2.3). Add section with at minimum a CI run URL or assessments/ path.\n' >&2
    return 1
  fi

  # Extract section body
  _tr_body="$(awk '
    /^## Test results[[:space:]]*$/ { in_tr=1; next }
    in_tr && /^## / { exit }
    in_tr { print }
  ' "$_ctrs_plan")"

  # Check for a URL or assessments/ path
  if printf '%s\n' "$_tr_body" | grep -qE 'https?://|assessments/' 2>/dev/null; then
    return 0
  fi

  printf '[gate-implemented] BLOCK: ## Test results section has no CI URL (https://) or assessments/ path; at minimum one link is required (§D2.3)\n' >&2
  return 1
}

# ---------------------------------------------------------------------------
# check_carry_forward_approved <plan_file>
# Verifies orianna_signature_approved is present and valid.
# ---------------------------------------------------------------------------
check_carry_forward_approved() {
  _ccfa_plan="$1"
  [ -f "$_ccfa_plan" ] || { printf '[gate-implemented] ERROR: plan not found: %s\n' "$_ccfa_plan" >&2; return 2; }

  _sig="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if(dashes==2) exit; next }
    dashes==1 && /^orianna_signature_approved:/ { print; exit }
  ' "$_ccfa_plan")"

  if [ -z "$_sig" ]; then
    printf '[gate-implemented] BLOCK: missing orianna_signature_approved in frontmatter; both prior-phase signatures required at implemented gate (§D2.3)\n' >&2
    return 1
  fi

  if [ ! -f "$ORIANNA_VERIFY" ]; then
    printf '[gate-implemented] ERROR: orianna-verify-signature.sh not found at %s\n' "$ORIANNA_VERIFY" >&2
    return 2
  fi

  _err="$(bash "$ORIANNA_VERIFY" "$_ccfa_plan" approved 2>&1)" && _rc=0 || _rc=$?
  if [ "$_rc" -ne 0 ]; then
    printf '[gate-implemented] BLOCK: approved-signature invalid: %s\n' "$_err" >&2
    printf '  Re-sign with: scripts/orianna-sign.sh <plan> approved, then re-sign in-progress, then retry (§D6.3)\n' >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# check_carry_forward_inprogress <plan_file>
# Verifies orianna_signature_in_progress is present and valid.
# ---------------------------------------------------------------------------
check_carry_forward_inprogress() {
  _ccfi_plan="$1"
  [ -f "$_ccfi_plan" ] || { printf '[gate-implemented] ERROR: plan not found: %s\n' "$_ccfi_plan" >&2; return 2; }

  _sig="$(awk '
    BEGIN { dashes=0 }
    /^---[[:space:]]*$/ { dashes++; if(dashes==2) exit; next }
    dashes==1 && /^orianna_signature_in_progress:/ { print; exit }
  ' "$_ccfi_plan")"

  if [ -z "$_sig" ]; then
    printf '[gate-implemented] BLOCK: missing orianna_signature_in_progress in frontmatter; both prior-phase signatures required at implemented gate (§D2.3)\n' >&2
    return 1
  fi

  if [ ! -f "$ORIANNA_VERIFY" ]; then
    printf '[gate-implemented] ERROR: orianna-verify-signature.sh not found at %s\n' "$ORIANNA_VERIFY" >&2
    return 2
  fi

  _err="$(bash "$ORIANNA_VERIFY" "$_ccfi_plan" in_progress 2>&1)" && _rc=0 || _rc=$?
  if [ "$_rc" -ne 0 ]; then
    printf '[gate-implemented] BLOCK: in-progress-signature invalid: %s\n' "$_err" >&2
    printf '  Re-sign with: scripts/orianna-sign.sh <plan> in_progress and retry (§D2.3)\n' >&2
    return 1
  fi

  return 0
}
