#!/usr/bin/env bash
# scripts/hooks/pre-commit-agent-shared-rules.sh
#
# Pre-commit hook for .claude/agents/ files — three checks per plan §D4.3a:
#
#   Check 1 — Shared-rules drift:
#     Each paired agent's inlined shared content must byte-match the canonical
#     _shared/<role>.md. Failure → "run sync-shared-rules.sh".
#
#   Check 2 — Pair-mate symmetry:
#     For any agent with `pair_mate: <other>`, verify <other>'s definition
#     carries `pair_mate: <this>` in reverse. Coordinators (agents with
#     `concern:` frontmatter) are exempt.
#
#   Check 3 — Model-frontmatter convention (§D1.1a):
#     Sonnet agents MUST declare `model: sonnet`; Opus agents MUST omit `model:`.
#     Cross-reference role_slot: + tier: against the §D1 matrix.
#     Missing `model:` on a Sonnet-role agent = error.
#     Declared `model: opus` on an Opus-role agent = warning (redundant).
#
# Usage: called by the strawberry pre-commit dispatcher or directly:
#   bash scripts/hooks/pre-commit-agent-shared-rules.sh [--agents-dir <path>]
#
# Exit codes:
#   0  all checks passed (warnings may have been emitted)
#   1  one or more blocking failures

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$SCRIPT_DIR/../.."
fi

AGENTS_DIR_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --agents-dir)
      shift
      AGENTS_DIR_OVERRIDE="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ -n "$AGENTS_DIR_OVERRIDE" ]; then
  AGENTS_DIR="$AGENTS_DIR_OVERRIDE"
else
  AGENTS_DIR="$REPO_ROOT/.claude/agents"
fi

SHARED_DIR="$AGENTS_DIR/_shared"

# ---------------------------------------------------------------------------
# Sonnet role-slot matrix — §D1
# Format: "<role_slot>:<tier>"  →  model family is "sonnet"
# Any slot+tier not listed here is expected to be Opus (omit model:).
# ---------------------------------------------------------------------------
is_sonnet_slot() {
  local role_slot="$1"
  local tier="$2"

  case "${role_slot}:${tier}" in
    # Row 4: test-impl
    "test-impl:complex")  return 0 ;;  # Rakan — Sonnet high
    "test-impl:normal")   return 0 ;;  # Vi    — Sonnet medium
    # Row 5: builder
    "builder:complex")    return 0 ;;  # Viktor — Sonnet high
    "builder:normal")     return 0 ;;  # Jayce  — Sonnet medium
    # Row 7: frontend-impl
    "frontend-impl:complex") return 0 ;;  # Seraphine — Sonnet medium
    "frontend-impl:normal")  return 0 ;;  # Soraka    — Sonnet low
    # Row 8: ai-specialist — Lux (complex) is OPUS; only Syndra (normal) is Sonnet
    "ai-specialist:normal")  return 0 ;;  # Syndra — Sonnet high
    # Quick lane (Karma + Talon) — only Talon is Sonnet; Karma is Opus
    "quick-executor:quick")  return 0 ;;  # Talon — Sonnet low
    # Single-lane Sonnet agents (must declare model: sonnet)
    "qa:single_lane")           return 0 ;;  # Akali — Sonnet medium
    "memory:single_lane")              return 0 ;;  # Skarner — Sonnet low
    "memory-consolidator:single_lane") return 0 ;;  # Lissandra — Sonnet medium
    "errand:single_lane")              return 0 ;;  # Yuumi — Sonnet low
    "devops-exec:single_lane")  return 0 ;;  # Ekko — Sonnet medium
    # Single-lane Opus agents fall through to default → caller treats as Opus
    # (devops-advice, pr-code-security, pr-fidelity, git-security, fact-check)
    *)
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Helper: extract a frontmatter field value from an agent .md file.
# Returns the first match of "^<field>: <value>" between the --- delimiters.
# Prints nothing and returns 1 if not found.
# ---------------------------------------------------------------------------
get_frontmatter_field() {
  local file="$1"
  local field="$2"

  awk -v field="$field" '
    BEGIN { in_fm = 0; delim_count = 0 }
    /^---[[:space:]]*$/ {
      delim_count++
      if (delim_count == 1) { in_fm = 1; next }
      if (delim_count == 2) { in_fm = 0; exit }
    }
    in_fm && $0 ~ "^" field ": " {
      sub("^" field ": ", "")
      sub("\r$", "")  # strip stray CR (CRLF-corrupted files)
      print
      exit
    }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Helper: extract inlined shared content from an agent file.
# Returns everything below the <!-- include: _shared/<role>.md --> marker.
# ---------------------------------------------------------------------------
get_inlined_content() {
  local file="$1"
  local role="$2"

  awk -v marker="<!-- include: _shared/${role}.md -->" '
    found { print; next }
    $0 == marker { found = 1 }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Determine which agent files to check:
#   - When running as a pre-commit hook: check staged .claude/agents/*.md files
#   - When called with --agents-dir (tests): check all *.md in that dir
# ---------------------------------------------------------------------------
get_agent_files() {
  if [ -n "$AGENTS_DIR_OVERRIDE" ]; then
    # Test mode: check all files in the provided dir
    for f in "$AGENTS_DIR"/*.md; do
      [ -f "$f" ] && printf '%s\n' "$f"
    done
  else
    # Hook mode: check staged files under .claude/agents/
    git diff --cached --name-only --diff-filter=ACMR 2>/dev/null \
      | grep '^\.claude/agents/[^/]*\.md$' \
      | while read -r rel; do printf '%s/%s\n' "$REPO_ROOT" "$rel"; done
  fi
}

fail=0
warn() { printf 'agent-shared-rules: WARN: %s\n' "$*" >&2; }
error() { printf 'agent-shared-rules: ERROR: %s\n' "$*" >&2; fail=1; }

# Collect agent files to check (may be empty — exit 0 fast)
agent_files="$(get_agent_files)"

if [ -z "$agent_files" ]; then
  exit 0
fi

# Also read all agent files in the dir for pair-mate cross-reference (check 2)
# We need the full roster, not just staged files.
all_agents_dir="$AGENTS_DIR"

# ---------------------------------------------------------------------------
# Check 1: Shared-rules drift
# ---------------------------------------------------------------------------
while IFS= read -r agent_file; do
  [ -f "$agent_file" ] || continue

  agent_basename="$(basename "$agent_file")"
  role_slot="$(get_frontmatter_field "$agent_file" "role_slot")"
  concern="$(get_frontmatter_field "$agent_file" "concern")"

  # Coordinators (have concern:) don't have shared files
  [ -n "$concern" ] && continue

  # Find include marker
  include_role=""
  while IFS= read -r line; do
    case "$line" in
      "<!-- include: _shared/"*)
        include_role="${line#<!-- include: _shared/}"
        include_role="${include_role%.md -->}"
        break
        ;;
    esac
  done < "$agent_file"

  # No include marker — skip (sync-shared-rules.sh handles this with a warning)
  [ -z "$include_role" ] && continue

  shared_file="$SHARED_DIR/${include_role}.md"

  if [ ! -f "$shared_file" ]; then
    # Missing shared file: not this hook's responsibility to error on (sync-shared-rules.sh does)
    # but we should warn
    warn "$agent_basename references missing shared file: _shared/${include_role}.md"
    continue
  fi

  # Extract inlined content (everything after the marker line)
  inlined="$(get_inlined_content "$agent_file" "$include_role")"
  canonical="$(cat "$shared_file")"

  if [ "$inlined" != "$canonical" ]; then
    error "$agent_basename: inlined shared content has drifted from _shared/${include_role}.md"
    printf '  Fix: run scripts/sync-shared-rules.sh\n' >&2
  fi

done <<EOF
$agent_files
EOF

# ---------------------------------------------------------------------------
# Check 2: Pair-mate symmetry
# ---------------------------------------------------------------------------
while IFS= read -r agent_file; do
  [ -f "$agent_file" ] || continue

  agent_basename="$(basename "$agent_file" .md)"
  concern="$(get_frontmatter_field "$agent_file" "concern")"

  # Coordinators are exempt
  [ -n "$concern" ] && continue

  pair_mate="$(get_frontmatter_field "$agent_file" "pair_mate")"

  # No pair_mate declared — skip (single-lane agents, or coordinator)
  [ -z "$pair_mate" ] && continue

  # Find the pair_mate's file
  mate_file="$all_agents_dir/${pair_mate}.md"

  if [ ! -f "$mate_file" ]; then
    error "$(basename "$agent_file"): pair_mate '${pair_mate}' has no definition file at ${mate_file}"
    continue
  fi

  # Check that pair_mate's file points back to this agent
  mate_pair_mate="$(get_frontmatter_field "$mate_file" "pair_mate")"

  if [ "$mate_pair_mate" != "$agent_basename" ]; then
    error "pair_mate asymmetry: ${agent_basename} → ${pair_mate}, but ${pair_mate} → '${mate_pair_mate}' (expected '${agent_basename}')"
  fi

done <<EOF
$agent_files
EOF

# ---------------------------------------------------------------------------
# Check 3: Model-frontmatter convention
# ---------------------------------------------------------------------------
while IFS= read -r agent_file; do
  [ -f "$agent_file" ] || continue

  agent_basename="$(basename "$agent_file")"
  concern="$(get_frontmatter_field "$agent_file" "concern")"

  # Coordinators: no model convention enforced (they inherit session default as Opus)
  [ -n "$concern" ] && continue

  model="$(get_frontmatter_field "$agent_file" "model")"
  role_slot="$(get_frontmatter_field "$agent_file" "role_slot")"
  tier="$(get_frontmatter_field "$agent_file" "tier")"

  # Determine expected model family based on role_slot + tier matrix
  if [ -n "$role_slot" ] && [ -n "$tier" ]; then
    if is_sonnet_slot "$role_slot" "$tier"; then
      # Expect model: sonnet to be declared
      if [ -z "$model" ]; then
        error "$agent_basename: role_slot=${role_slot} tier=${tier} requires 'model: sonnet' in frontmatter (§D1.1a)"
      elif [ "$model" != "sonnet" ]; then
        error "$agent_basename: role_slot=${role_slot} tier=${tier} requires 'model: sonnet', found 'model: ${model}'"
      fi
    else
      # Expect no model: field (Opus inherits session default)
      if [ "$model" = "opus" ]; then
        warn "$agent_basename: 'model: opus' is redundant — Opus agents should omit model: (§D1.1a)"
      fi
      # model: sonnet on an Opus slot is an error
      if [ "$model" = "sonnet" ]; then
        error "$agent_basename: role_slot=${role_slot} tier=${tier} is an Opus slot but declares 'model: sonnet'"
      fi
    fi
  else
    # role_slot or tier missing: we can only check for the redundant opus declaration
    if [ "$model" = "opus" ]; then
      warn "$agent_basename: 'model: opus' is redundant — Opus agents should omit model: (§D1.1a)"
    fi
  fi

done <<EOF
$agent_files
EOF

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  printf 'agent-shared-rules: commit blocked. fix the above errors.\n' >&2
  exit 1
fi
exit 0
