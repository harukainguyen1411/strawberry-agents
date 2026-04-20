#!/bin/sh
# _lib_orianna_estimates.sh — Sourceable lib: validate estimate_minutes in plan ## Tasks section.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D4, T4.3
#
# Provides:
#   check_estimate_minutes <plan_file>
#     Returns 0 if all task entries have valid estimate_minutes values.
#     Returns non-zero with stderr diagnosis on any violation.
#
# Validation rules (§D4):
#   1. Every task entry (line matching '^- \[[ x]\]') must contain
#      'estimate_minutes:' followed by whitespace and an integer.
#   2. Integer must satisfy 1 <= n <= 60.
#   3. No alternative unit literals ('hours', 'days', 'weeks', 'h)', '(d)')
#      anywhere in the ## Tasks section body.
#
# Usage (sourced):
#   . scripts/_lib_orianna_estimates.sh
#   check_estimate_minutes path/to/plan.md
#
# Do NOT add a shebang execution entry — this file is sourced-only.

# Guard against double-sourcing.
_LIB_ORIANNA_ESTIMATES_LOADED=1

# check_estimate_minutes <plan_file>
# Reads the ## Tasks section of the plan; validates every task entry.
# Returns 0 on clean pass, non-zero on any violation.
check_estimate_minutes() {
  _cem_plan="$1"
  [ -n "$_cem_plan" ] || { printf '[lib-estimates] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cem_plan" ] || { printf '[lib-estimates] ERROR: plan file not found: %s\n' "$_cem_plan" >&2; return 2; }

  _cem_fail=0

  # --- Extract the ## Tasks section ---
  # Collect lines from '## Tasks' through the next '##' heading or end of file.
  _cem_tasks="$(awk '
    /^## Tasks[[:space:]]*$/ { in_tasks=1; next }
    in_tasks && /^## / { exit }
    in_tasks { print }
  ' "$_cem_plan")"

  # If no Tasks section at all, that is not this function's concern — it just
  # means there are no task entries to validate. Return 0.
  if [ -z "$_cem_tasks" ]; then
    return 0
  fi

  # --- Check 1: every task entry has estimate_minutes: <integer in [1,60]> ---
  # Task entries: lines starting with '- [ ]' or '- [x]' (case-insensitive on x)
  printf '%s\n' "$_cem_tasks" | while IFS= read -r _line; do
    case "$_line" in
      '- [ ]'*|'- [x]'*|'- [X]'*)
        # This is a task entry line. Check for estimate_minutes field.
        case "$_line" in
          *estimate_minutes:*)
            # Extract the integer value after 'estimate_minutes:'
            _val="$(printf '%s\n' "$_line" | sed 's/.*estimate_minutes:[[:space:]]*//' | sed 's/[^0-9-].*//' | tr -d ' ')"
            # Validate: must be a plain integer (no leading minus for positive,
            # but we want to catch negatives too)
            case "$_val" in
              ''|*[!0-9-]*)
                printf '[lib-estimates] BLOCK: estimate_minutes value is not an integer in task: %s\n' "$_line" >&2
                exit 1
                ;;
              -*)
                printf '[lib-estimates] BLOCK: estimate_minutes: %s is negative (must be 1-60): %s\n' "$_val" "$_line" >&2
                exit 1
                ;;
              *)
                # Check bounds: 1 <= n <= 60
                if [ "$_val" -lt 1 ] 2>/dev/null; then
                  printf '[lib-estimates] BLOCK: estimate_minutes: %s is below minimum (1): %s\n' "$_val" "$_line" >&2
                  exit 1
                fi
                if [ "$_val" -gt 60 ] 2>/dev/null; then
                  printf '[lib-estimates] BLOCK: estimate_minutes: %s exceeds maximum (60); task must be decomposed (§D4): %s\n' "$_val" "$_line" >&2
                  exit 1
                fi
                ;;
            esac
            ;;
          *)
            printf '[lib-estimates] BLOCK: task entry missing estimate_minutes: field (§D4): %s\n' "$_line" >&2
            exit 1
            ;;
        esac
        ;;
    esac
  done || return 1

  # --- Check 2: no alternative unit literals in Tasks section ---
  _alt_units="hours days weeks"
  for _unit in $_alt_units; do
    if printf '%s\n' "$_cem_tasks" | grep -qw "$_unit" 2>/dev/null; then
      printf '[lib-estimates] BLOCK: alternative time unit "%s" found in ## Tasks section; use estimate_minutes only (§D4)\n' "$_unit" >&2
      _cem_fail=1
    fi
  done

  # Check for 'h)' and '(d)' patterns (word-boundary-less, exact substring)
  if printf '%s\n' "$_cem_tasks" | grep -q 'h)' 2>/dev/null; then
    printf '[lib-estimates] BLOCK: alternative time unit "h)" found in ## Tasks section; use estimate_minutes only (§D4)\n' >&2
    _cem_fail=1
  fi
  if printf '%s\n' "$_cem_tasks" | grep -q '(d)' 2>/dev/null; then
    printf '[lib-estimates] BLOCK: alternative time unit "(d)" found in ## Tasks section; use estimate_minutes only (§D4)\n' >&2
    _cem_fail=1
  fi

  return "$_cem_fail"
}
