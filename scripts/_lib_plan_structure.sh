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
_LIB_PLAN_STRUCTURE_DIR="${_LIB_PLAN_STRUCTURE_DIR:-$(cd "$(dirname "${BASH_SOURCE:-$0}")" 2>/dev/null && pwd || echo "scripts")}"

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
# Implements the same rules as check_estimate_minutes from _lib_orianna_estimates.sh
# using a single awk pass for performance (< 200ms for 10 plans target, §T3).
#
# Rules (matching §D4 and _lib_orianna_estimates.sh):
#   1. Every task entry (- [ ] or - [x]) must have estimate_minutes: <integer in 1-60>.
#   2. Banned unit literals (hours, days, weeks, h), (d)) must not appear in the
#      ## Tasks section body — checked outside of backtick spans.
# Returns 0 on clean pass, non-zero with [lib-plan-structure] BLOCK: messages on stderr.
check_task_estimates() {
  _cte_plan="$1"
  [ -n "$_cte_plan" ] || { printf '[lib-plan-structure] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cte_plan" ] || { printf '[lib-plan-structure] ERROR: plan file not found: %s\n' "$_cte_plan" >&2; return 2; }

  # Single awk pass over the plan file.
  # Handles both `## Tasks` and `## N. Tasks` headings.
  # Strips inline backtick spans before checking banned literals and estimate extraction
  # to prevent false positives from DoD prose that mentions these tokens.
  awk '
    # Enter tasks section on either heading form
    /^## Tasks[[:space:]]*$/ || /^## [0-9]+\. Tasks[[:space:]]*$/ {
      in_tasks = 1
      next
    }
    # Exit tasks section on the next ## heading
    in_tasks && /^## / { in_tasks = 0 }

    in_tasks {
      line = $0

      # Strip inline backtick spans to get the "prose" version of the line
      prose = line
      while (match(prose, /`[^`]*`/)) {
        prose = substr(prose, 1, RSTART-1) substr(prose, RSTART+RLENGTH)
      }

      # Check 1: task entry lines must have estimate_minutes: <int in 1-60>
      if (prose ~ /^- \[[ xX]\]/) {
        if (prose !~ /estimate_minutes:/) {
          print "[lib-plan-structure] BLOCK: task entry missing estimate_minutes: field (§D4): " line | "cat >&2"
          fail = 1
        } else {
          # Extract value: find first estimate_minutes: occurrence (not greedy over multiple)
          val = prose
          sub(/.*estimate_minutes:[[:space:]]*/, "", val)
          # Extract leading integer (may be followed by non-digit)
          match(val, /^-?[0-9]+/)
          if (RLENGTH < 1) {
            print "[lib-plan-structure] BLOCK: estimate_minutes value is not an integer in task: " line | "cat >&2"
            fail = 1
          } else {
            n = substr(val, 1, RLENGTH) + 0
            if (n < 1) {
              print "[lib-plan-structure] BLOCK: estimate_minutes: " n " is below minimum (1): " line | "cat >&2"
              fail = 1
            } else if (n > 60) {
              print "[lib-plan-structure] BLOCK: estimate_minutes: " n " exceeds maximum (60); task must be decomposed (§D4): " line | "cat >&2"
              fail = 1
            }
          }
        }
      }

      # Check 2: no alternative unit literals in prose (outside backtick spans)
      # Only check once per unit per section (flag file used to suppress duplicates)
      if (!hours_flagged && prose ~ /\bhours\b/) {
        print "[lib-plan-structure] BLOCK: alternative time unit \"hours\" found in ## Tasks section; use estimate_minutes only (§D4)" | "cat >&2"
        fail = 1; hours_flagged = 1
      }
      if (!days_flagged && prose ~ /\bdays\b/) {
        print "[lib-plan-structure] BLOCK: alternative time unit \"days\" found in ## Tasks section; use estimate_minutes only (§D4)" | "cat >&2"
        fail = 1; days_flagged = 1
      }
      if (!weeks_flagged && prose ~ /\bweeks\b/) {
        print "[lib-plan-structure] BLOCK: alternative time unit \"weeks\" found in ## Tasks section; use estimate_minutes only (§D4)" | "cat >&2"
        fail = 1; weeks_flagged = 1
      }
      if (!hparen_flagged && index(prose, "h)") > 0) {
        print "[lib-plan-structure] BLOCK: alternative time unit \"h)\" found in ## Tasks section; use estimate_minutes only (§D4)" | "cat >&2"
        fail = 1; hparen_flagged = 1
      }
      if (!dparen_flagged && index(prose, "(d)") > 0) {
        print "[lib-plan-structure] BLOCK: alternative time unit \"(d)\" found in ## Tasks section; use estimate_minutes only (§D4)" | "cat >&2"
        fail = 1; dparen_flagged = 1
      }
    }

    END { exit fail }
  ' "$_cte_plan"
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
    false|'false'|'False'|'FALSE') return 0 ;;
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
