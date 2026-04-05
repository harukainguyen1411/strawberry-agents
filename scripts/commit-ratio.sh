#!/usr/bin/env bash
# commit-ratio.sh — classify commits as infra or output, report ratio
# Usage:
#   ./scripts/commit-ratio.sh             # ratio since beginning
#   ./scripts/commit-ratio.sh --week      # last 7 days
#   ./scripts/commit-ratio.sh --since 2026-04-01  # since date
#   ./scripts/commit-ratio.sh --verbose   # show per-commit classification

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# --- Flags ---
SINCE=""
VERBOSE=false
WEEK=false

for arg in "$@"; do
  case "$arg" in
    --week) WEEK=true ;;
    --verbose) VERBOSE=true ;;
    --since) SINCE_NEXT=true ;;
    *)
      if [ "${SINCE_NEXT:-false}" = true ]; then
        SINCE="$arg"
        SINCE_NEXT=false
      fi
      ;;
  esac
done

if [ "$WEEK" = true ]; then
  SINCE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)
fi

# --- Infra classification ---
# A commit is INFRA if its message prefix or changed paths match infra patterns.

classify_commit() {
  local hash="$1"
  local msg="$2"

  # Infra by commit message prefix
  case "$msg" in
    chore:*|ops:*|fix:\ agent*|fix:\ restart*|fix:\ heartbeat*|fix:\ mcp*|fix:\ token*|fix:\ inject*|fix:\ poll*|fix:\ deliver*)
      echo "infra"; return ;;
  esac

  # Output by commit message prefix
  case "$msg" in
    feat:*|feature:*)
      # Check if it's an agent tooling feature vs user-facing feature
      ;;
  esac

  # Check changed paths
  local paths
  paths=$(git diff-tree --no-commit-id -r --name-only "$hash" 2>/dev/null || true)

  local infra_path_match=false
  local output_path_match=false

  while IFS= read -r path; do
    case "$path" in
      agents/*|scripts/*|architecture/*|plans/*|assessments/*|\
      .github/*|*.sh|CLAUDE.md|.gitignore|.gitleaks.toml|\
      agents/health/*|agents/memory/*|agents/*/memory/*|\
      agents/*/journal/*|agents/*/learnings/*)
        infra_path_match=true ;;
      myapps/*|apps/*|services/*|discord-bot/*|src/*)
        output_path_match=true ;;
    esac
  done <<< "$paths"

  # If paths are mixed, infra wins (conservative)
  if [ "$infra_path_match" = true ]; then
    echo "infra"; return
  fi
  if [ "$output_path_match" = true ]; then
    echo "output"; return
  fi

  # Fallback: check message keywords
  case "$msg" in
    *discord\ bot\ feature*|*user-facing*|*new\ app*|*new\ service*|*client\ project*)
      echo "output"; return ;;
    *memory*|*journal*|*protocol*|*heartbeat*|*mcp*|*git\ workflow*|*branch\ protection*|\
    *agent\ state*|*agent\ tooling*|*ops\ script*|*safe-checkout*|*token\ inject*)
      echo "infra"; return ;;
  esac

  # Default: infra (conservative — assume ops unless clearly output)
  echo "infra"
}

# --- Collect commits ---
GIT_LOG_ARGS=(log --format="%H %s")
if [ -n "$SINCE" ]; then
  GIT_LOG_ARGS+=(--since="$SINCE")
fi

infra_count=0
output_count=0
infra_commits=()
output_commits=()

while IFS= read -r line; do
  hash="${line%% *}"
  msg="${line#* }"
  classification=$(classify_commit "$hash" "$msg")

  if [ "$classification" = "infra" ]; then
    infra_count=$((infra_count + 1))
    infra_commits+=("$hash $msg")
  else
    output_count=$((output_count + 1))
    output_commits+=("$hash $msg")
  fi
done < <(git "${GIT_LOG_ARGS[@]}" 2>/dev/null)

total=$((infra_count + output_count))

# --- Report ---
if [ "$WEEK" = true ]; then
  echo "=== Commit Ratio — Last 7 days (since $SINCE) ==="
elif [ -n "$SINCE" ]; then
  echo "=== Commit Ratio — Since $SINCE ==="
else
  echo "=== Commit Ratio — All time ==="
fi
echo ""

if [ "$total" -eq 0 ]; then
  echo "No commits found."
  exit 0
fi

infra_pct=$(( infra_count * 100 / total ))
output_pct=$(( output_count * 100 / total ))

echo "Total:  $total commits"
echo "Infra:  $infra_count ($infra_pct%)"
echo "Output: $output_count ($output_pct%)"
echo ""

# Threshold check (April 10 onwards, infra must be < 30%)
today=$(date +%Y-%m-%d)
if [[ "$today" > "2026-04-10" ]] || [[ "$today" = "2026-04-10" ]]; then
  if [ "$infra_pct" -ge 30 ]; then
    echo "⚠  WARNING: Infra ratio is ${infra_pct}% — target is <30%"
  else
    echo "✓  Infra ratio ${infra_pct}% is within target (<30%)"
  fi
fi

if [ "$VERBOSE" = true ]; then
  echo ""
  echo "--- INFRA commits ---"
  for c in "${infra_commits[@]+"${infra_commits[@]}"}"; do
    echo "  $c"
  done
  echo ""
  echo "--- OUTPUT commits ---"
  for c in "${output_commits[@]+"${output_commits[@]}"}"; do
    echo "  $c"
  done
fi
