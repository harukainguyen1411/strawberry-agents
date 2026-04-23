#!/usr/bin/env bash
# pretooluse-inbox-write-guard.test.sh — xfail / unit tests for inbox-write-guard.
# Plan: plans/approved/personal/2026-04-23-inbox-write-guard.md
#
# Drives scripts/hooks/pretooluse-inbox-write-guard.sh by piping synthetic JSON payloads.
# All six cases must pass (exit 0 from the test harness) after T1 ships; this file
# is committed FIRST (xfail semantics per Rule 12) before the guard script exists.
#
# Run: bash scripts/hooks/tests/pretooluse-inbox-write-guard.test.sh
# Exit 0 — all cases pass; non-zero — one or more failures.

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

# --- Summary ---
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ]
