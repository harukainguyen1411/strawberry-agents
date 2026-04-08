#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

FORMAT="${1:-tsv}"
if [ "${1:-}" = "--format" ]; then
  FORMAT="${2:-tsv}"
fi

# _is_agent_dir: true if dir has a memory/ subdirectory
_is_agent_dir() {
  [ -d "$1/memory" ]
}

_get_role() {
  local profile="$1/profile.md"
  if [ ! -f "$profile" ]; then
    echo "unknown"
    return
  fi
  # Look for ## Role section, take the first non-empty line after it
  awk '/^## Role/{found=1; next} found && /^[^#]/ && NF{print; exit}' "$profile" \
    | sed 's/^[[:space:]-]*//' \
    | sed 's/^[*_]//; s/[*_]$//'
  # If nothing found, return unknown
}

collect_agents() {
  for dir in "$REPO_ROOT/agents"/*/; do
    [ -d "$dir" ] || continue
    _is_agent_dir "$dir" || continue
    name="$(basename "$dir")"
    role="$(_get_role "$dir")"
    [ -n "$role" ] || role="unknown"
    echo "$name|$role"
  done
}

if [ "$FORMAT" = "json" ]; then
  echo "["
  first=1
  while IFS='|' read -r name role; do
    if [ "$first" = "1" ]; then
      first=0
    else
      echo ","
    fi
    # Escape double quotes in role
    role_escaped="${role//\"/\\\"}"
    printf '  {"name": "%s", "role": "%s"}' "$name" "$role_escaped"
  done < <(collect_agents)
  echo ""
  echo "]"
else
  # TSV: name TAB role
  while IFS='|' read -r name role; do
    printf '%s\t%s\n' "$name" "$role"
  done < <(collect_agents)
fi
