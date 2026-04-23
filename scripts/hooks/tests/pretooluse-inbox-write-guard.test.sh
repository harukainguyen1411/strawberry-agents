#!/usr/bin/env bash
# pretooluse-inbox-write-guard.test.sh — xfail / unit tests for inbox-write-guard.
# Plan: plans/approved/personal/2026-04-23-inbox-write-guard.md
#
# Drives scripts/hooks/pretooluse-inbox-write-guard.sh by piping synthetic JSON payloads.
# All cases must pass (exit 0 from the test harness) after fixes ship.
#
# Run: bash scripts/hooks/tests/pretooluse-inbox-write-guard.test.sh
# Exit 0 — all cases pass; non-zero — one or more failures.
#
# Round-3 changes (2026-04-23):
#   - Removed case (g): STRAWBERRY_SKILL env-var bypass removed from guard.
#     /agent-ops send now writes via bash script — no Write tool, no bypass needed.
#   - Removed case (h): moot once bypass removed.
#   - Added case (n): Edit where "status: pending" appears only in body (not frontmatter)
#     must still be blocked — guard must anchor the match to frontmatter line only.
#   - Added case (o): read_at value must match ISO-8601 shape; non-ISO value blocked.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD="$SCRIPT_DIR/../pretooluse-inbox-write-guard.sh"
PASS=0
FAIL=0

run_case() {
  _label="$1"
  _payload="$2"
  _expected_exit="$3"
  _env_overrides="${4:-}"  # space-separated KEY=VALUE pairs

  # Build env-override prefix
  _env_prefix=""
  if [ -n "$_env_overrides" ]; then
    for _pair in $_env_overrides; do
      _env_prefix="$_env_prefix $_pair"
    done
  fi

  # Run guard with optional env overrides, capture exit code
  if [ -n "$_env_prefix" ]; then
    _actual_exit=0
    env $_env_prefix bash "$GUARD" <<< "$_payload" >/dev/null 2>&1 || _actual_exit=$?
  else
    _actual_exit=0
    env -i HOME="${HOME:-/tmp}" PATH="$PATH" bash "$GUARD" <<< "$_payload" >/dev/null 2>&1 || _actual_exit=$?
  fi

  if [ "$_actual_exit" = "$_expected_exit" ]; then
    printf '[PASS] %s\n' "$_label"
    PASS=$((PASS + 1))
  else
    printf '[FAIL] %s — expected exit %s, got %s\n' "$_label" "$_expected_exit" "$_actual_exit"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================================
# Original cases a-f (invariant 1: basic block/allow)
# ============================================================================

# --- Case a: Write to inbox top-level, no identity — expect exit 2 (blocked) -----
run_case "a: Write to inbox, no identity" \
  '{"tool_name":"Write","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","content":"msg"}}' \
  2

# --- Case b: Same Write with admin identity Duongntd — expect exit 0 (allowed) ---
run_case "b: Write to inbox, admin identity Duongntd" \
  '{"tool_name":"Write","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","content":"msg"}}' \
  0 \
  "CLAUDE_AGENT_NAME=Duongntd"

# --- Case c: Edit — check-inbox status flip (pending -> read) — expect exit 0 ---
run_case "c: Edit inbox — status pending->read flip (check-inbox)" \
  '{"tool_name":"Edit","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","old_string":"status: pending","new_string":"status: read"}}' \
  0

# --- Case d: Write to archive subtree — expect exit 0 (archive exempt) ----------
run_case "d: Write to inbox/archive subtree — exempt" \
  '{"tool_name":"Write","tool_input":{"file_path":"agents/evelynn/inbox/archive/2026-04/abc12345.md","content":"msg"}}' \
  0

# --- Case e: Edit inbox — body change, NOT status flip — expect exit 2 -----------
run_case "e: Edit inbox — body change not status flip — blocked" \
  '{"tool_name":"Edit","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","old_string":"## body\noriginal text","new_string":"## body\nupdated text"}}' \
  2

# --- Case f: Non-inbox path — expect exit 0 (guard ignores) ----------------------
run_case "f: Write to non-inbox path — guard ignores" \
  '{"tool_name":"Write","tool_input":{"file_path":"plans/proposed/personal/foo.md","content":"plan"}}' \
  0

# ============================================================================
# Fix 1 (CRITICAL): env-var bypass removed — /agent-ops send uses bash script.
# Cases (g) and (h) removed: STRAWBERRY_SKILL bypass no longer exists in guard.
# Write to inbox is always blocked unless admin identity.
# ============================================================================

# ============================================================================
# Fix 2 (IMPORTANT): Edit allow-rule tightening — only status line may change
# ============================================================================

# --- Case i: Edit — status flip with extra read_at line added — expect exit 0 ---
run_case "i: Edit inbox — status flip + read_at added — allowed" \
  '{"tool_name":"Edit","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","old_string":"from: sona\nstatus: pending\n","new_string":"from: sona\nstatus: read\nread_at: 2026-04-23 10:00\n"}}' \
  0

# --- Case j: Edit — status line present but also body changes — expect exit 2 ---
run_case "j: Edit inbox — status flip + body change smuggled — blocked" \
  '{"tool_name":"Edit","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","old_string":"status: pending\n## body\noriginal","new_string":"status: read\n## body\nupdated"}}' \
  2

# ============================================================================
# Fix 3 (IMPORTANT): MultiEdit dropped from matcher — guard ignores tool_name=MultiEdit
# ============================================================================

# --- Case k: MultiEdit to inbox path — guard should pass through (exit 0) ----
# (MultiEdit removed from matcher in settings.json, so guard won't fire;
# but if it does fire, verify guard itself doesn't crash — exit 0 for unknown tool)
run_case "k: MultiEdit to inbox path — guard ignores (unknown tool passthrough)" \
  '{"tool_name":"MultiEdit","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","edits":[]}}' \
  0

# ============================================================================
# Fix 4 (IMPORTANT): Absolute-path bypass — normalize path before check
# ============================================================================

# --- Case l: Write with absolute path to inbox — expect exit 2 (blocked) ---
run_case "l: Write to inbox with absolute path — blocked" \
  '{"tool_name":"Write","tool_input":{"file_path":"/some/repo/agents/evelynn/inbox/abc12345.md","content":"msg"}}' \
  2

# --- Case m: Write with path traversal (../../agents/...) — expect exit 2 ------
run_case "m: Write to inbox via path traversal — blocked" \
  '{"tool_name":"Write","tool_input":{"file_path":"plans/../agents/evelynn/inbox/abc12345.md","content":"msg"}}' \
  2

# ============================================================================
# Fix 5 (MINOR): status line must be frontmatter-anchored (^status: pending$)
# ============================================================================

# --- Case n: Edit where "status: pending" appears only in body text — blocked ---
# The body text contains the phrase but the frontmatter line is already "status: read".
# Guard must NOT allow this — the match must be on a standalone frontmatter line only.
run_case "n: Edit — status: pending in body only, frontmatter already read — blocked" \
  '{"tool_name":"Edit","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","old_string":"status: read\n\nThis message has status: pending items.\n","new_string":"status: read\n\nThis message has status: pending items.\nread_at: 2026-04-23T10:00:00Z\n"}}' \
  2

# ============================================================================
# Fix 6 (MINOR): read_at value must match ISO-8601 shape
# ============================================================================

# --- Case o: Edit — read_at value is not ISO-8601 — blocked ---
run_case "o: Edit inbox — read_at with non-ISO value — blocked" \
  '{"tool_name":"Edit","tool_input":{"file_path":"agents/evelynn/inbox/abc12345.md","old_string":"status: pending\n","new_string":"status: read\nread_at: not-a-date\n"}}' \
  2

# --- Summary ---
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ]
