#!/bin/sh
# _lib_plan_structure.sh — Sourceable lib: deterministic structural checks for plan files.
#
# Plan: plans/approved/personal/2026-04-20-plan-structure-prelint.md §3
#
# Provides four public functions (run independently or via orchestrator):
#   check_plan_frontmatter <plan_file>   — Step A: required YAML frontmatter keys
#   check_task_estimates <plan_file>     — Step B: delegate to _lib_orianna_estimates.sh
#   check_test_plan_present <plan_file>  — Step D: ## Test plan section when tests_required
#   check_plan_structure <plan_file>     — Orchestrator: runs A, B, D in order
#
# Error messages use prefix [lib-plan-structure] BLOCK: to match Orianna prompt wording.
# All functions return 0 on clean pass, non-zero on any violation (stderr diagnosis).
#
# Do NOT add a shebang execution entry — this file is sourced-only.

# Resolve the lib directory so we can source sibling libs regardless of caller cwd.
# shellcheck disable=SC3028
_LIB_PLAN_STRUCTURE_DIR="${_LIB_PLAN_STRUCTURE_DIR:-$(cd "$(dirname "${BASH_SOURCE:-$0}")" 2>/dev/null && pwd || echo "scripts")}"

# Source sibling: _lib_orianna_estimates.sh — single source of truth for estimate checks.
# guard against double-sourcing
if [ -z "${_LIB_ORIANNA_ESTIMATES_LOADED:-}" ]; then
  # shellcheck source=scripts/_lib_orianna_estimates.sh
  . "$_LIB_PLAN_STRUCTURE_DIR/_lib_orianna_estimates.sh"
fi

# check_plan_frontmatter <plan_file>
# Verifies all required YAML frontmatter keys are present and non-empty.
# Required keys: status, concern, owner, created, orianna_gate_version, tests_required
# Returns 0 on clean pass, non-zero with [lib-plan-structure] BLOCK: messages on stderr.
check_plan_frontmatter() {
  _cpf_plan="$1"
  [ -n "$_cpf_plan" ] || { printf '[lib-plan-structure] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cpf_plan" ] || { printf '[lib-plan-structure] ERROR: plan file not found: %s\n' "$_cpf_plan" >&2; return 2; }

  # Extract frontmatter block (between first two --- lines)
  _cpf_fm="$(awk '/^---/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm{print}' "$_cpf_plan")"

  _cpf_fail=0

  # Required keys — each must be present and have a non-empty value on the same line
  # shellcheck disable=SC2016  # backticks in printf format string are literal markdown, not subshell
  for _key in status concern owner created orianna_gate_version tests_required; do
    # Match 'key: value' — value must not be empty
    _val="$(printf '%s\n' "$_cpf_fm" | awk -v k="$_key" '
      $0 ~ "^" k ":[[:space:]]" {
        sub("^" k ":[[:space:]]*", "")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        if (length($0) > 0) { print $0 }
      }
    ')"
    if [ -z "$_val" ]; then
      printf '[lib-plan-structure] BLOCK: missing required frontmatter field: `%s:`\n' "$_key" >&2
      _cpf_fail=1
    fi
  done

  return "$_cpf_fail"
}

# check_task_estimates <plan_file>
# Validates estimate_minutes fields in the ## Tasks (or ## N. Tasks) section.
# Delegates to check_estimate_minutes from _lib_orianna_estimates.sh (single source
# of truth, §3 / §5 / T1 — no logic duplication).
# Returns 0 on clean pass, non-zero with BLOCK messages on stderr.
check_task_estimates() {
  _cte_plan="$1"
  [ -n "$_cte_plan" ] || { printf '[lib-plan-structure] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cte_plan" ] || { printf '[lib-plan-structure] ERROR: plan file not found: %s\n' "$_cte_plan" >&2; return 2; }

  # Delegate to the canonical estimate validator — no duplicated logic.
  check_estimate_minutes "$_cte_plan"
}

# check_test_plan_present <plan_file>
# When tests_required: true (or field absent — default true), requires a
# `## Test plan` heading with at least one non-blank, non-heading line before
# the next `## ` heading or EOF.
# Returns 0 on clean pass, non-zero with BLOCK message on failure.
check_test_plan_present() {
  _ctp_plan="$1"
  [ -n "$_ctp_plan" ] || { printf '[lib-plan-structure] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_ctp_plan" ] || { printf '[lib-plan-structure] ERROR: plan file not found: %s\n' "$_ctp_plan" >&2; return 2; }

  # Read tests_required from frontmatter
  _ctp_fm="$(awk '/^---/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm{print}' "$_ctp_plan")"
  _ctp_tr="$(printf '%s\n' "$_ctp_fm" | awk '/^tests_required:/{sub(/^tests_required:[[:space:]]*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); print; exit}')"

  # Default to true when field is absent or blank
  case "$_ctp_tr" in
    false|False|FALSE) return 0 ;;
  esac

  # tests_required is true (or defaulted to true): check ## Test plan section exists
  # and has at least one non-blank, non-heading line
  _ctp_found="$(awk '
    /^## Test plan[[:space:]]*$/ { in_section=1; next }
    in_section && /^## / { exit }
    in_section && /[^[:space:]]/ && !/^#/ { found=1; exit }
    END { if (found) print "yes" }
  ' "$_ctp_plan")"

  if [ "$_ctp_found" != "yes" ]; then
    # shellcheck disable=SC2016  # backticks are literal markdown, not subshell
    printf '[lib-plan-structure] BLOCK: tests_required is true but `## Test plan` section is missing or empty\n' >&2
    return 1
  fi

  return 0
}

# check_plan_structure <plan_file>
# Orchestrator: runs check_plan_frontmatter (A), check_task_estimates (B),
# check_test_plan_present (D) in order. Returns 0 only if all pass.
# Aggregates all BLOCK messages to stderr.
check_plan_structure() {
  _cps_plan="$1"
  [ -n "$_cps_plan" ] || { printf '[lib-plan-structure] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cps_plan" ] || { printf '[lib-plan-structure] ERROR: plan file not found: %s\n' "$_cps_plan" >&2; return 2; }

  _cps_fail=0

  check_plan_frontmatter "$_cps_plan" || _cps_fail=1
  check_task_estimates "$_cps_plan"   || _cps_fail=1
  check_test_plan_present "$_cps_plan" || _cps_fail=1

  return "$_cps_fail"
}
