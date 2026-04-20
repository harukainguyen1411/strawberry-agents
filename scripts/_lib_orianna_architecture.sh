#!/bin/sh
# _lib_orianna_architecture.sh — Sourceable lib: verify architecture declaration in plan.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D5, T4.4
#
# Provides:
#   check_architecture_declaration <plan_file> <repo_root> <approved_timestamp>
#     Returns 0 if the plan has a valid architecture declaration.
#     Returns non-zero with stderr diagnosis on any violation.
#
# Rules (§D5): The plan MUST contain exactly ONE of:
#   Option A — frontmatter key 'architecture_changes:' listing paths under architecture/.
#              Each listed path must exist AND have a git-log commit modifying it
#              after <approved_timestamp>.
#   Option B — frontmatter key 'architecture_impact: none' with a non-empty
#              '## Architecture impact' section body in the plan body.
#
# Usage (sourced):
#   . scripts/_lib_orianna_architecture.sh
#   check_architecture_declaration plan.md /path/to/repo 2026-04-20T10:00:00Z
#
# <approved_timestamp> is an ISO-8601 UTC datetime string from the
# orianna_signature_approved value.

# check_architecture_declaration <plan_file> <repo_root> <approved_timestamp>
check_architecture_declaration() {
  _cad_plan="$1"
  _cad_repo="$2"
  _cad_ts="$3"

  [ -n "$_cad_plan" ] || { printf '[lib-arch] ERROR: no plan file argument\n' >&2; return 2; }
  [ -f "$_cad_plan" ] || { printf '[lib-arch] ERROR: plan file not found: %s\n' "$_cad_plan" >&2; return 2; }
  [ -n "$_cad_repo" ] || { printf '[lib-arch] ERROR: no repo_root argument\n' >&2; return 2; }
  [ -d "$_cad_repo" ] || { printf '[lib-arch] ERROR: repo_root not a directory: %s\n' "$_cad_repo" >&2; return 2; }

  # --- Extract frontmatter ---
  _cad_fm="$(awk 'BEGIN{d=0} /^---[[:space:]]*$/{d++; if(d==2) exit; next} d==1{print}' "$_cad_plan")"

  # Check which option is present
  _has_changes=0
  _has_impact_none=0

  printf '%s\n' "$_cad_fm" | grep -q '^architecture_changes:' && _has_changes=1
  printf '%s\n' "$_cad_fm" | grep -q '^architecture_impact:[[:space:]]*none' && _has_impact_none=1

  # --- Check: neither present → block ---
  if [ "$_has_changes" -eq 0 ] && [ "$_has_impact_none" -eq 0 ]; then
    printf '[lib-arch] BLOCK: plan missing architecture declaration; declare either\n' >&2
    printf '  architecture_changes: [list-of-paths] OR\n' >&2
    printf '  architecture_impact: none + ## Architecture impact section (§D5)\n' >&2
    return 1
  fi

  # --- Option A: architecture_changes list ---
  if [ "$_has_changes" -eq 1 ]; then
    # Extract the list of paths from YAML list under architecture_changes:
    # Format may be:
    #   architecture_changes:
    #     - path/to/file.md
    #     - path/to/other.md
    # OR inline: architecture_changes: [path1, path2]  (not supported — only block-style)
    _cad_paths="$(awk '
      BEGIN { in_list=0 }
      /^architecture_changes:/ { in_list=1; next }
      in_list && /^[[:space:]]*-[[:space:]]/ {
        sub(/^[[:space:]]*-[[:space:]]*/, "")
        gsub(/[[:space:]]*$/, "")
        print
        next
      }
      in_list && /^[^[:space:]]/ { exit }
    ' "$_cad_plan")"

    if [ -z "$_cad_paths" ]; then
      printf '[lib-arch] BLOCK: architecture_changes: field is present but list is empty (§D5)\n' >&2
      return 1
    fi

    _cad_fail=0
    printf '%s\n' "$_cad_paths" | while IFS= read -r _path; do
      [ -n "$_path" ] || continue

      # Check path exists
      if [ ! -f "$_cad_repo/$_path" ] && [ ! -d "$_cad_repo/$_path" ]; then
        printf '[lib-arch] BLOCK: listed architecture path "%s" does not exist in repo (§D5)\n' "$_path" >&2
        exit 1
      fi

      # Check git-log entry after approved_timestamp
      if [ -n "$_cad_ts" ]; then
        _commits="$(git -C "$_cad_repo" log --after="$_cad_ts" --follow --format='%H' -- "$_path" 2>/dev/null)"
        if [ -z "$_commits" ]; then
          printf '[lib-arch] BLOCK: architecture path "%s" has no git commit modifying it after approved-signature timestamp "%s" (§D5)\n' "$_path" "$_cad_ts" >&2
          exit 1
        fi
      fi
    done || return 1

    return 0
  fi

  # --- Option B: architecture_impact: none with ## Architecture impact section ---
  if [ "$_has_impact_none" -eq 1 ]; then
    # Extract the ## Architecture impact section body
    _cad_body="$(awk '
      BEGIN { in_section=0 }
      /^## Architecture impact[[:space:]]*$/ { in_section=1; next }
      in_section && /^## / { exit }
      in_section {
        # Check for non-empty content
        line=$0
        gsub(/[[:space:]]/, "", line)
        if (length(line) > 0) { print; count++ }
      }
      END { }
    ' "$_cad_plan")"

    if [ -z "$_cad_body" ]; then
      printf '[lib-arch] BLOCK: architecture_impact: none declared but ## Architecture impact section is missing or empty; add a one-line justification (§D5)\n' >&2
      return 1
    fi

    return 0
  fi

  # Should not reach here
  return 1
}
