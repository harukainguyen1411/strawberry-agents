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
# Required keys: status, concern, owner, created, tests_required
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
  for _key in status concern owner created tests_required; do
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

# check_qa_plan_frontmatter <plan_file>
# T6b — Validates qa_plan frontmatter field:
#   - Field must be present (BLOCK: "qa_plan field missing")
#   - Value must be one of: required | inline | none (BLOCK: "invalid qa_plan value")
#   - When value is "required": qa_co_author must also be present (BLOCK: "qa_co_author")
#   - When value is "none": qa_plan_none_justification must be present (BLOCK: "justification")
# Returns 0 on clean pass, non-zero with [lib-plan-structure] BLOCK: messages on stderr.
check_qa_plan_frontmatter() {
  _cqpf_plan="$1"
  [ -n "$_cqpf_plan" ] || { printf '[lib-plan-structure] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cqpf_plan" ] || { printf '[lib-plan-structure] ERROR: plan file not found: %s\n' "$_cqpf_plan" >&2; return 2; }

  # Extract frontmatter block (between first two --- lines)
  _cqpf_fm="$(awk '/^---/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm{print}' "$_cqpf_plan")"

  # Extract qa_plan value — strip surrounding YAML quotes (I2)
  _cqpf_val="$(printf '%s\n' "$_cqpf_fm" | awk '/^qa_plan:/{sub(/^qa_plan:[[:space:]]*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); gsub(/^["'"'"']|["'"'"']$/,""); print; exit}')"

  # Field must be present
  if [ -z "$_cqpf_val" ]; then
    printf '[lib-plan-structure] BLOCK: qa_plan field missing — every plan must declare qa_plan: required | inline | none\n' >&2
    return 1
  fi

  # Value must be one of the three allowed values
  case "$_cqpf_val" in
    required|inline|none) ;;
    *)
      printf '[lib-plan-structure] BLOCK: invalid qa_plan value "%s" — must be one of: required, inline, none\n' "$_cqpf_val" >&2
      return 1
      ;;
  esac

  _cqpf_fail=0

  # When qa_plan: required — qa_co_author must be present and must be lulu or senna (I2, I4)
  if [ "$_cqpf_val" = "required" ]; then
    _cqpf_coauthor="$(printf '%s\n' "$_cqpf_fm" | awk '/^qa_co_author:/{sub(/^qa_co_author:[[:space:]]*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); gsub(/^["'"'"']|["'"'"']$/,""); print; exit}')"
    if [ -z "$_cqpf_coauthor" ]; then
      printf '[lib-plan-structure] BLOCK: qa_plan: required but qa_co_author field is missing — set qa_co_author: lulu (UI) or qa_co_author: senna (backend)\n' >&2
      _cqpf_fail=1
    else
      # I4: whitelist — only lulu and senna are valid co-authors
      case "$_cqpf_coauthor" in
        lulu|senna) ;;
        *)
          printf '[lib-plan-structure] BLOCK: invalid qa_co_author value "%s" — must be one of: lulu, senna\n' "$_cqpf_coauthor" >&2
          _cqpf_fail=1
          ;;
      esac
    fi
  fi

  # When qa_plan: none — qa_plan_none_justification must be present and non-trivial (I2, I3)
  if [ "$_cqpf_val" = "none" ]; then
    _cqpf_just="$(printf '%s\n' "$_cqpf_fm" | awk '/^qa_plan_none_justification:/{sub(/^qa_plan_none_justification:[[:space:]]*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); gsub(/^["'"'"']|["'"'"']$/,""); print; exit}')"
    if [ -z "$_cqpf_just" ]; then
      printf '[lib-plan-structure] BLOCK: qa_plan: none requires qa_plan_none_justification field — add a one-line justification explaining why there is no QA surface\n' >&2
      _cqpf_fail=1
    elif [ "${#_cqpf_just}" -lt 10 ]; then
      # I3: minimum length — single-character or trivially short justifications are not meaningful
      printf '[lib-plan-structure] BLOCK: qa_plan_none_justification is too short (minimum 10 characters) — provide a meaningful one-line justification\n' >&2
      _cqpf_fail=1
    fi
  fi

  return "$_cqpf_fail"
}

# _QA_PLAN_REQUIRED_SUBHEADINGS — single named constant for T7b and T8 reuse.
# Each entry is a ### sub-heading that MUST appear under ## QA Plan when qa_plan: required.
_QA_PLAN_REQUIRED_SUBHEADINGS="### Acceptance criteria
### Happy path (user flow)
### Failure modes (what could break)
### QA artifacts expected"

# check_qa_plan_body <plan_file>
# T7b — Validates the ## QA Plan body section:
#   - When qa_plan: required: ## QA Plan section must exist AND contain all four
#     required sub-headings (BLOCK names each missing sub-heading specifically)
#   - When qa_plan: inline: ## QA Plan section must exist (no sub-heading enforcement)
#   - When qa_plan: none: no body section required (function returns 0 immediately)
# Returns 0 on clean pass, non-zero with [lib-plan-structure] BLOCK: messages on stderr.
check_qa_plan_body() {
  _cqpb_plan="$1"
  [ -n "$_cqpb_plan" ] || { printf '[lib-plan-structure] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cqpb_plan" ] || { printf '[lib-plan-structure] ERROR: plan file not found: %s\n' "$_cqpb_plan" >&2; return 2; }

  # Extract qa_plan value from frontmatter — strip surrounding YAML quotes (I2)
  _cqpb_fm="$(awk '/^---/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm{print}' "$_cqpb_plan")"
  _cqpb_val="$(printf '%s\n' "$_cqpb_fm" | awk '/^qa_plan:/{sub(/^qa_plan:[[:space:]]*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); gsub(/^["'"'"']|["'"'"']$/,""); print; exit}')"

  # qa_plan: none — no body section required
  if [ "$_cqpb_val" = "none" ]; then
    return 0
  fi

  # For required and inline: ## QA Plan section must be present and have content.
  # C1: track fenced code blocks so that ## QA Plan inside a ``` example is not
  # mistaken for the real section heading.
  _cqpb_section="$(awk '
    /^```/ { fence = !fence; next }
    !fence && /^## QA Plan[[:space:]]*$/ { in_section=1; next }
    !fence && in_section && /^## / { exit }
    in_section { print }
  ' "$_cqpb_plan")"

  # Check section exists and has at least one non-blank line
  _cqpb_has_content="$(printf '%s\n' "$_cqpb_section" | awk '/[^[:space:]]/{found=1; exit} END{if(found) print "yes"}')"

  if [ -z "$_cqpb_section" ] || [ "$_cqpb_has_content" != "yes" ]; then
    printf '[lib-plan-structure] BLOCK: qa_plan is set but ## QA Plan section is missing or empty in the plan body\n' >&2
    return 1
  fi

  # qa_plan: inline — section present is sufficient (no sub-heading enforcement)
  if [ "$_cqpb_val" = "inline" ]; then
    return 0
  fi

  # qa_plan: required — verify all four required sub-headings are present.
  # C2+C3: use here-doc instead of printf|while to avoid subshell state loss and
  # eliminate the PID-named tempfile that caused spurious REJECT on PID reuse.
  # I1: normalize each line of the extracted section (strip trailing CR/spaces) before
  # comparing with grep -xF (fixed-string exact match) — avoids regex metachar issues
  # with headings like "### Failure modes (what could break)" while still tolerating
  # trailing whitespace and Windows CRLF line endings from editors.
  _cqpb_section_norm="$(printf '%s\n' "$_cqpb_section" | sed 's/[[:space:]]*$//')"
  _cqpb_fail=0
  while IFS= read -r _heading; do
    # Normalize _heading: strip any trailing CR/spaces so the fixed-string match is clean
    _heading="$(printf '%s' "$_heading" | sed 's/[[:space:]]*$//')"
    # I1: fixed-string exact-line match against the whitespace-normalized section
    if ! printf '%s\n' "$_cqpb_section_norm" | grep -qxF "$_heading"; then
      _heading_name="${_heading#\#\#\# }"
      printf '[lib-plan-structure] BLOCK: ## QA Plan section is missing required sub-heading: %s\n' "$_heading_name" >&2
      _cqpb_fail=1
    fi
  done <<EOF
$_QA_PLAN_REQUIRED_SUBHEADINGS
EOF

  return "$_cqpb_fail"
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
