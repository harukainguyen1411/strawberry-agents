#!/usr/bin/env bash
# pretooluse-uxspec-gate.sh — PreToolUse dispatch-gate hook (Rule 22 / Stream C)
#
# Plan:  plans/approved/personal/2026-04-25-frontend-uiux-in-process.md §D2/D9
# Tasks: T-C2 (skeleton), T-C3 (path-glob + plan extraction), T-C4 (decision + block)
#
# Fires before every Agent tool dispatch. Reads the PreToolUse JSON payload from
# stdin and blocks Seraphine / Soraka dispatches against UI-touching plans that
# lack a §UX Spec section (or a UX-Waiver: frontmatter bypass).
#
# Input:  JSON on stdin — {"tool_name": "Agent", "tool_input": {...}}
# Output: nothing on exit 0 (allow); block message on stderr + exit 2 (block)
#
# Portability: POSIX-portable bash. Uses python3 for JSON parsing (already a
# repo dep via agent-default-isolation.sh and other hooks).
#
# Log: every dispatch decision (allow/block/why) is appended to
#      .claude/logs/uxspec-gate.log for OQ-5 false-positive observability.
#
# Exit codes:
#   0 — allowed (not in scope, or plan passes the gate)
#   2 — blocked (UI plan missing §UX Spec and no UX-Waiver)

set -eu

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export REPO_ROOT

LOG_DIR="$REPO_ROOT/.claude/logs"
LOG_FILE="$LOG_DIR/uxspec-gate.log"

# ── Logging helper ────────────────────────────────────────────────────────────
_log() {
  mkdir -p "$LOG_DIR"
  printf '[uxspec-gate] %s\n' "$*" >> "$LOG_FILE" 2>/dev/null || true
}

# ── Python3 decision engine ───────────────────────────────────────────────────
# We use a single python3 invocation to handle JSON parsing, plan reading, and
# all gate logic. The script prints one of:
#   ALLOW <reason>
#   BLOCK <reason>
#   or exits with code 1 on hard error.
#
# The bash wrapper translates ALLOW→exit-0, BLOCK→exit-2+stderr.

SCRIPT_FILE="$(mktemp)"
trap 'rm -f "$SCRIPT_FILE"' EXIT

cat > "$SCRIPT_FILE" <<'PY'
import json
import os
import re
import sys

# ── Constants ─────────────────────────────────────────────────────────────────

GATED_AGENTS = {"seraphine", "soraka"}

# UI surface path-glob patterns (D1 in ADR).
# A plan is considered UI-touching when any of its Tasks `files:` references
# or inline backtick paths match one of these patterns.
#
# Unambiguously frontend extensions: .vue, .tsx, .jsx, .css, .scss
# These always indicate a UI surface regardless of package context.
#
# Ambiguous extensions: .ts, .js — only flagged as UI when found in
# clearly frontend package contexts (components/, pages/, routes/ dir, or
# known frontend package names). Backend packages (api/, functions/,
# migrations/) are excluded to avoid false-positives (e.g. apps/api/src/routes/).
UI_PATTERNS = [
    # Unambiguously frontend file types
    re.compile(r"apps/[^\s]+\.(?:vue|tsx|jsx|css|scss)\b"),
    # TypeScript/JS only in clearly frontend contexts
    re.compile(r"apps/(?!api/|functions/|backend/)[^\s]*/(?:components|pages|views|ui|store|composables|hooks)/[^\s]+\.(?:ts|js)\b"),
    # apps/**/components/ directory (any file)
    re.compile(r"apps/[^\s]+/components/[^\s]+"),
    # apps/**/pages/ directory (any file)
    re.compile(r"apps/[^\s]+/pages/[^\s]+"),
    # frontend-named packages with src/
    re.compile(r"apps/(?:frontend|web|client|portal|ui|app)[^\s]*/src/[^\s]+\.(?:ts|js)\b"),
]

# Plan path pattern: match any .md file path in the description.
# Handles both relative plans/ paths and absolute /path/to/file.md paths.
# We look for paths that end in .md, preceded by a non-space/non-quote char,
# and may be absolute (/...) or relative (plans/...).
PLAN_PATH_RE = re.compile(
    r"(?:^|[\s\"'(])([^\s\"'()]*\.md)(?:[\s\"'()$]|$)"
)

# Frontmatter UX-Waiver pattern (case-insensitive key)
WAIVER_RE = re.compile(r"(?mi)^ux-waiver\s*:", re.IGNORECASE)

# §UX Spec heading pattern
UXSPEC_HEADING_RE = re.compile(r"^##\s+UX\s+Spec\s*$", re.MULTILINE | re.IGNORECASE)

# ── Helpers ───────────────────────────────────────────────────────────────────

def is_ui_touching(plan_body):
    """Return True if the plan body references any UI surface file paths."""
    for pat in UI_PATTERNS:
        if pat.search(plan_body):
            return True
    return False


def has_waiver(plan_body):
    """
    Return True if the plan's YAML frontmatter contains a UX-Waiver: key
    (case-insensitive). Only checks within the frontmatter block (between
    the first pair of --- delimiters).
    """
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", plan_body, re.DOTALL)
    if m:
        fm = m.group(1)
        return bool(WAIVER_RE.search(fm))
    return False


def has_nonempty_uxspec(plan_body):
    """
    Return True if the plan contains a '## UX Spec' heading followed by at
    least one non-blank line of content before the next ## heading or EOF.

    An empty heading (only whitespace before the next ## or EOF) returns False.
    """
    m = UXSPEC_HEADING_RE.search(plan_body)
    if not m:
        return False

    # Text after the heading
    rest = plan_body[m.end():]
    # Find next ## heading or end of string
    next_heading = re.search(r"^##\s", rest, re.MULTILINE)
    if next_heading:
        section_body = rest[:next_heading.start()]
    else:
        section_body = rest

    # Check for any non-blank content in the section body
    return bool(section_body.strip())


def lulu_or_neeko(plan_body):
    """
    Return advisory routing hint based on plan complexity frontmatter.
    D6: complex → Neeko; standard/trivial/absent → Lulu.
    """
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", plan_body, re.DOTALL)
    if m:
        fm = m.group(1)
        cx_match = re.search(r"^\s*complexity\s*:\s*(\S+)", fm, re.MULTILINE)
        if cx_match:
            cx = cx_match.group(1).lower().strip('"').strip("'")
            if cx == "complex":
                return "Neeko (complex-track designer)"
            return "Lulu (normal-track design advisor)"
    return "Lulu (normal-track design advisor) or Neeko (complex-track designer)"


# ── Main ──────────────────────────────────────────────────────────────────────

raw = sys.stdin.read()
if not raw.strip():
    print("ALLOW no-input")
    sys.exit(0)

try:
    d = json.loads(raw)
except Exception:
    print("ALLOW json-parse-error")
    sys.exit(0)

tool_name = d.get("tool_name") or ""
tool_input = d.get("tool_input") or {}

if tool_name != "Agent":
    print("ALLOW not-agent-tool")
    sys.exit(0)

if not isinstance(tool_input, dict):
    print("ALLOW tool-input-not-dict")
    sys.exit(0)

subagent = (tool_input.get("subagent_type") or "").lower()

if subagent not in GATED_AGENTS:
    print("ALLOW agent-not-in-gated-set subagent=%s" % subagent)
    sys.exit(0)

# Extract plan path(s) from description
description = tool_input.get("description") or ""
plan_paths = PLAN_PATH_RE.findall(" " + description + " ")
# Deduplicate while preserving order
seen = set()
unique_plans = []
for p in plan_paths:
    if p not in seen:
        seen.add(p)
        unique_plans.append(p)
plan_paths = unique_plans

if not plan_paths:
    print("ALLOW no-plan-path-in-description subagent=%s" % subagent)
    sys.exit(0)

repo_root = os.environ.get("REPO_ROOT", ".")

# Gate: check each plan referenced in the dispatch
for rel_path in plan_paths:
    # Handle both absolute paths and relative paths
    if os.path.isabs(rel_path):
        full_path = rel_path
    else:
        full_path = os.path.join(repo_root, rel_path)
    if not os.path.isfile(full_path):
        # Plan file not found — allow (cannot gate what we cannot read)
        print("ALLOW plan-file-not-found path=%s" % rel_path)
        continue

    with open(full_path, "r", encoding="utf-8") as fh:
        plan_body = fh.read()

    # Is the plan even UI-touching?
    if not is_ui_touching(plan_body):
        print("ALLOW non-ui-plan path=%s" % rel_path)
        continue

    # UX-Waiver bypass (case-insensitive)
    if has_waiver(plan_body):
        print("ALLOW ux-waiver path=%s" % rel_path)
        continue

    # §UX Spec present with non-empty body?
    if has_nonempty_uxspec(plan_body):
        print("ALLOW ux-spec-present path=%s" % rel_path)
        continue

    # Block.
    advisor = lulu_or_neeko(plan_body)
    print(
        "BLOCK missing-uxspec subagent=%s path=%s advisor=%s"
        % (subagent, rel_path, advisor)
    )
    # Also write the block details to stdout for the bash wrapper to use
    # (bash reads only the first line for ALLOW/BLOCK decision; advisor is
    #  embedded in the line for the bash wrapper to extract)
    sys.exit(2)

# All plans checked — allow
print("ALLOW all-plans-passed subagent=%s" % subagent)
sys.exit(0)
PY

# ── Run the Python engine and translate its output ────────────────────────────

# Capture stdin first (we need to pipe it to python)
STDIN_CONTENT="$(cat)"

DECISION_FILE="$(mktemp)"
# Disable set -e temporarily to capture non-zero python3 exit codes
set +e
printf '%s' "$STDIN_CONTENT" | python3 "$SCRIPT_FILE" > "$DECISION_FILE" 2>/dev/null
PY_EXIT=$?
set -e
DECISION="$(cat "$DECISION_FILE")"
rm -f "$DECISION_FILE"

_log "decision='$DECISION' py_exit=$PY_EXIT"

if [ "$PY_EXIT" -eq 2 ]; then
    # Block: emit a clear diagnostic to stderr naming the routing agents
    # Extract fields from the BLOCK line
    _subagent="$(printf '%s' "$DECISION" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
m = re.search(r'subagent=(\S+)', line)
print(m.group(1) if m else 'unknown')
" 2>/dev/null || true)"

    _path="$(printf '%s' "$DECISION" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
m = re.search(r'path=(\S+)', line)
print(m.group(1) if m else 'unknown')
" 2>/dev/null || true)"

    _advisor="$(printf '%s' "$DECISION" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
m = re.search(r'advisor=(.+)', line)
print(m.group(1) if m else 'Lulu (normal-track design advisor) or Neeko (complex-track designer)')
" 2>/dev/null || true)"

    _block_msg="$(printf '[uxspec-gate] BLOCKED: %s dispatch on %s\n[uxspec-gate] Plan is missing a UX Spec section (or UX-Waiver: frontmatter).\n[uxspec-gate] Next step: dispatch %s to author the UX Spec.\n[uxspec-gate] Route to: lulu (normal-track) or neeko (complex-track) per D6.\n[uxspec-gate]   Re-dispatch %s once the spec is in place.\n[uxspec-gate] Bypass: add "UX-Waiver: <reason>" to plan frontmatter for refactors\n[uxspec-gate]   with no visible delta, child plans of an approved parent spec,\n[uxspec-gate]   or an explicit Duong waiver (per CLAUDE.md Rule 22).\n' \
      "$_subagent" "$_path" "$_advisor" "$_subagent")"
    # Write to both stdout and stderr so tests / IDE output both surface it
    printf '%s' "$_block_msg"
    printf '%s' "$_block_msg" >&2
    exit 2
fi

# Allow: exit 0
exit 0
