#!/usr/bin/env bash
# xfail: implements plans/in-progress/2026-04-20-strawberry-inbox-channel.md
#
# Unit harness for inbox-watch.sh, inbox-watch-bootstrap.sh, and
# the check-inbox archive flow.
#
# Run: bash scripts/hooks/tests/inbox-watch-test.sh
#
# xfail wrapper semantics (per ADR §Tasks IW.0):
#   run_xfail <fn>: if fn exits 0 (passes), print XFAIL (expected before impl).
#                   If fn exits non-0 (fails), print FAIL (unexpected even now).
#   run_real <fn>:  regression floor tests — always run as real assertions.
#
# The harness exits 0 when:
#   - No FAIL (real assertion failures)
#   - No XPASS (tests that should be xfail but already pass unexpectedly)
#
# Viktor strips the xfail wrapper in IW.5 once all scripts are in place.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WATCHER="$REPO_ROOT/scripts/hooks/inbox-watch.sh"
BOOTSTRAP="$REPO_ROOT/scripts/hooks/inbox-watch-bootstrap.sh"

PASS=0
FAIL=0
XFAIL_COUNT=0
XPASS_COUNT=0

# ────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }
xfail() { printf 'XFAIL: %s\n' "$1"; XFAIL_COUNT=$((XFAIL_COUNT+1)); }
xpass() { printf 'XPASS (unexpected): %s\n' "$1"; XPASS_COUNT=$((XPASS_COUNT+1)); }

# run_xfail <fn>
# For impl-dependent tests: we expect them to FAIL right now (impl not landed).
# If the function exits non-0 (assertion fails) → XFAIL (expected, good).
# If the function exits 0 (assertion passes) → XPASS (unexpected before impl, bad).
run_xfail() {
  local fn="$1"
  if "$fn" 2>/dev/null; then
    xpass "$fn"
  else
    xfail "$fn"
  fi
}

# run_real <fn>
# For regression / invariant tests that should always pass regardless of impl.
run_real() {
  local fn="$1"
  if "$fn" 2>/dev/null; then
    pass "$fn"
  else
    fail "$fn"
  fi
}

# Create a minimal pending inbox message file
make_pending_msg() {
  local path="$1"
  local from="${2:-sona}"
  local priority="${3:-high}"
  local ts="${4:-2026-04-21T14:23:00Z}"
  cat > "$path" <<EOF
---
from: ${from}
to: evelynn
priority: ${priority}
timestamp: ${ts}
status: pending
---

This is a test message body.
EOF
}

# Create a read (archived) inbox message file
make_read_msg() {
  local path="$1"
  cat > "$path" <<EOF
---
from: sona
to: evelynn
priority: normal
timestamp: 2026-04-21T12:00:00Z
status: read
read_at: 2026-04-21T12:05:00Z
---

This message has already been read.
EOF
}

# ────────────────────────────────────────────────────────────────
# Fixture setup helpers
# ────────────────────────────────────────────────────────────────

setup_fixture_empty() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/agents/evelynn/inbox"
  printf '%s' "$dir"
}

setup_fixture_one_pending() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/agents/evelynn/inbox"
  make_pending_msg "$dir/agents/evelynn/inbox/20260421-1423-sona-alert.md" "sona" "high" "2026-04-21T14:23:00Z"
  printf '%s' "$dir"
}

setup_fixture_mixed() {
  # one pending + one read in inbox/ + archive with stale + fresh files
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/agents/evelynn/inbox"
  mkdir -p "$dir/agents/evelynn/inbox/archive/2026-03"
  mkdir -p "$dir/agents/evelynn/inbox/archive/2026-04"
  make_pending_msg "$dir/agents/evelynn/inbox/pending-msg.md" "sona" "normal" "2026-04-21T10:00:00Z"
  make_read_msg "$dir/agents/evelynn/inbox/read-msg.md"
  # Stale archive file: mtime > 7 days ago
  make_read_msg "$dir/agents/evelynn/inbox/archive/2026-03/stale.md"
  touch -t 202604110000 "$dir/agents/evelynn/inbox/archive/2026-03/stale.md"
  # Fresh archive file: default mtime (now)
  make_read_msg "$dir/agents/evelynn/inbox/archive/2026-04/fresh.md"
  printf '%s' "$dir"
}

# ────────────────────────────────────────────────────────────────
# IW.1 — Watcher tests (xfail — require inbox-watch.sh)
# ────────────────────────────────────────────────────────────────

# Guard: all watcher tests require the script to exist
watcher_exists() {
  [ -f "$WATCHER" ] && [ -x "$WATCHER" ]
}

test_boot_sweep_emits_one_line_per_pending() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_one_pending)"
  local out
  out="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  local line_count
  line_count="$(printf '%s\n' "$out" | grep -c 'INBOX:' || true)"
  [ "$line_count" -eq 1 ]
}

test_boot_sweep_empty_inbox_emits_nothing() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_empty)"
  local out
  out="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  [ -z "$out" ]
}

test_line_format_contract() {
  # em-dash in the format: U+2014 —
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_one_pending)"
  local out
  out="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  # Pattern: INBOX: <filename>.md — from <sender> — <priority>
  printf '%s\n' "$out" | grep -qE '^INBOX: [^ ]+\.md — from [^ ]+ — [a-z]+$'
}

test_identity_resolution_chain() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_one_pending)"

  # Source 1: CLAUDE_AGENT_NAME
  local out1
  out1="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  # Must emit at least one INBOX line via CLAUDE_AGENT_NAME
  printf '%s\n' "$out1" | grep -q 'INBOX:'
}

test_identity_source2_strawberry_agent() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_one_pending)"
  local out
  out="$(INBOX_WATCH_ONESHOT=1 STRAWBERRY_AGENT=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  printf '%s\n' "$out" | grep -q 'INBOX:'
}

test_no_identity_exits_cleanly() {
  watcher_exists || return 1
  local dir
  dir="$(mktemp -d)"
  # No env vars that resolve to an agent, no settings.json in this dir
  local exit_code=0
  INBOX_WATCH_ONESHOT=1 REPO_ROOT="$dir" bash "$WATCHER" >/dev/null 2>&1 || exit_code=$?
  [ "$exit_code" -eq 0 ]
}

test_unknown_agent_exits_cleanly() {
  watcher_exists || return 1
  local exit_code=0
  INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=nonexistent bash "$WATCHER" >/dev/null 2>&1 || exit_code=$?
  [ "$exit_code" -eq 0 ]
}

test_no_inbox_watch_opt_out_suppresses_watcher() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_mixed)"
  touch "$dir/.no-inbox-watch"
  local out
  out="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  [ -z "$out" ]
  # Stale archive file must survive (Phase 0 did NOT run when opted out)
  [ -f "$dir/agents/evelynn/inbox/archive/2026-03/stale.md" ]
}

test_archive_subdir_not_swept_by_phase1() {
  watcher_exists || return 1
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/agents/evelynn/inbox/archive/2026-04"
  # Put a pending-looking file inside archive/ subdir — should NOT be emitted
  make_pending_msg "$dir/agents/evelynn/inbox/archive/2026-04/archived-pending.md"
  local out
  out="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  [ -z "$out" ]
}

test_frontmatter_without_status_never_emits() {
  watcher_exists || return 1
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/agents/evelynn/inbox"
  cat > "$dir/agents/evelynn/inbox/no-status.md" <<'EOF'
---
from: sona
to: evelynn
priority: normal
timestamp: 2026-04-21T10:00:00Z
---

No status field in frontmatter.
EOF
  local out
  out="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  [ -z "$out" ]
}

test_status_read_never_emits() {
  watcher_exists || return 1
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/agents/evelynn/inbox"
  make_read_msg "$dir/agents/evelynn/inbox/already-read.md"
  local out
  out="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" 2>/dev/null)"
  [ -z "$out" ]
}

# ────────────────────────────────────────────────────────────────
# Archive retention tests — Phase 0 (xfail — require inbox-watch.sh)
# ────────────────────────────────────────────────────────────────

test_archive_retention_deletes_stale_files() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_mixed)"
  INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" >/dev/null 2>&1
  [ ! -f "$dir/agents/evelynn/inbox/archive/2026-03/stale.md" ]
}

test_archive_retention_preserves_fresh_files() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_mixed)"
  INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" >/dev/null 2>&1
  [ -f "$dir/agents/evelynn/inbox/archive/2026-04/fresh.md" ]
}

test_archive_retention_prunes_empty_month_buckets() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_mixed)"
  INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" >/dev/null 2>&1
  # 2026-03/ had only stale.md — now empty, should be pruned
  [ ! -d "$dir/agents/evelynn/inbox/archive/2026-03" ]
  # 2026-04/ still has fresh.md — must survive
  [ -d "$dir/agents/evelynn/inbox/archive/2026-04" ]
}

test_archive_cleanup_noop_when_archive_dir_absent() {
  watcher_exists || return 1
  local dir
  dir="$(setup_fixture_empty)"
  local exit_code=0
  INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$dir" bash "$WATCHER" >/dev/null 2>&1 || exit_code=$?
  [ "$exit_code" -eq 0 ]
}

# ────────────────────────────────────────────────────────────────
# /check-inbox archive flow tests (IW.3)
# We exercise the documented shell steps from SKILL.md as a shell
# equivalent. In IW.5 these become real assertions against the
# skill's actual behaviour.
# ────────────────────────────────────────────────────────────────

# Guard: check-inbox tests require SKILL.md to exist (IW.3 deliverable)
checkinbox_skill_exists() {
  [ -f "$REPO_ROOT/.claude/skills/check-inbox/SKILL.md" ]
}

# Helper: run the check-inbox archive flow steps against a fixture dir.
# Replicates the documented steps from SKILL.md §3-4 as shell ops.
# Requires SKILL.md to exist (guard above).
run_check_inbox_flow() {
  local inbox_dir="$1"
  local now_utc
  now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  for f in "$inbox_dir"/*.md; do
    [ -f "$f" ] || continue
    grep -q 'status: pending' "$f" || continue
    ts="$(grep '^timestamp:' "$f" | head -1 | sed 's/timestamp: *//' | tr -d ' ')"
    if [ -n "$ts" ]; then
      bucket="$(printf '%s' "$ts" | cut -c1-7)"
    else
      bucket="$(date -r "$f" +%Y-%m 2>/dev/null || date +%Y-%m)"
    fi
    archive_dir="$inbox_dir/archive/$bucket"
    mkdir -p "$archive_dir"
    filename="$(basename "$f")"
    tmpfile="$(mktemp)"
    awk -v now="$now_utc" '
      /^status: pending/ { print "status: read"; print "read_at: " now; next }
      { print }
    ' "$f" > "$tmpfile"
    mv "$tmpfile" "$f"
    mv "$f" "$archive_dir/$filename"
  done
}

test_check_inbox_moves_pending_to_archive_yyyy_mm() {
  checkinbox_skill_exists || return 1
  local dir
  dir="$(setup_fixture_one_pending)"
  local inbox_dir="$dir/agents/evelynn/inbox"
  run_check_inbox_flow "$inbox_dir"
  local pending_count
  pending_count="$(find "$inbox_dir" -maxdepth 1 -name '*.md' | xargs grep -l 'status: pending' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$pending_count" -eq 0 ]
  [ -f "$inbox_dir/archive/2026-04/20260421-1423-sona-alert.md" ]
  grep -q 'status: read' "$inbox_dir/archive/2026-04/20260421-1423-sona-alert.md"
  grep -qE 'read_at: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "$inbox_dir/archive/2026-04/20260421-1423-sona-alert.md"
}

test_check_inbox_archive_fallback_to_mtime_when_no_timestamp() {
  checkinbox_skill_exists || return 1
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/agents/evelynn/inbox"
  cat > "$dir/agents/evelynn/inbox/no-ts-msg.md" <<'EOF'
---
from: sona
to: evelynn
priority: normal
status: pending
---

No timestamp in this message.
EOF
  local inbox_dir="$dir/agents/evelynn/inbox"
  run_check_inbox_flow "$inbox_dir"
  local archived
  archived="$(find "$inbox_dir/archive" -name 'no-ts-msg.md' 2>/dev/null)"
  [ -n "$archived" ]
  grep -q 'status: read' "$archived"
}

# ────────────────────────────────────────────────────────────────
# Bootstrap hook tests (IW.2 — xfail — require inbox-watch-bootstrap.sh)
# ────────────────────────────────────────────────────────────────

bootstrap_exists() {
  [ -f "$BOOTSTRAP" ] && [ -x "$BOOTSTRAP" ]
}

test_bootstrap_emits_json_on_startup() {
  bootstrap_exists || return 1
  local out
  out="$(printf '{"source":"startup"}' | CLAUDE_AGENT_NAME=evelynn bash "$BOOTSTRAP" 2>/dev/null)"
  printf '%s\n' "$out" | jq -e . >/dev/null 2>&1
  printf '%s\n' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1
  printf '%s\n' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'invoke the Monitor tool'
  printf '%s\n' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'scripts/hooks/inbox-watch.sh'
  printf '%s\n' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -qi 'evelynn'
}

test_bootstrap_silent_on_resume() {
  bootstrap_exists || return 1
  local out
  out="$(printf '{"source":"resume"}' | CLAUDE_AGENT_NAME=evelynn bash "$BOOTSTRAP" 2>/dev/null)"
  [ -z "$out" ]
}

test_bootstrap_silent_on_clear() {
  bootstrap_exists || return 1
  local out
  out="$(printf '{"source":"clear"}' | CLAUDE_AGENT_NAME=evelynn bash "$BOOTSTRAP" 2>/dev/null)"
  [ -z "$out" ]
}

test_bootstrap_silent_on_compact() {
  bootstrap_exists || return 1
  local out
  out="$(printf '{"source":"compact"}' | CLAUDE_AGENT_NAME=evelynn bash "$BOOTSTRAP" 2>/dev/null)"
  [ -z "$out" ]
}

test_bootstrap_opt_out_honored() {
  bootstrap_exists || return 1
  local tmpdir
  tmpdir="$(mktemp -d)"
  touch "$tmpdir/.no-inbox-watch"
  local out
  out="$(printf '{"source":"startup"}' | CLAUDE_AGENT_NAME=evelynn REPO_ROOT="$tmpdir" bash "$BOOTSTRAP" 2>/dev/null)"
  [ -z "$out" ]
}

# ────────────────────────────────────────────────────────────────
# Settings wiring test (IW.4 — xfail — requires settings.json edit)
# ────────────────────────────────────────────────────────────────

test_settings_json_has_bootstrap_entry() {
  local count
  count="$(jq -e '.hooks.SessionStart[0].hooks | length' "$REPO_ROOT/.claude/settings.json" 2>/dev/null)"
  [ "$count" -ge 2 ]
  local cmd
  cmd="$(jq -r '.hooks.SessionStart[0].hooks[1].command' "$REPO_ROOT/.claude/settings.json" 2>/dev/null)"
  [ "$cmd" = "bash scripts/hooks/inbox-watch-bootstrap.sh" ]
}

# ────────────────────────────────────────────────────────────────
# Regression floor (always-real tests — not xfail)
# These invariants must hold regardless of impl state.
# ────────────────────────────────────────────────────────────────

test_regression_no_channels_artifacts() {
  # Must not find strawberry-inbox plugin artifacts
  ! grep -rn 'strawberry-inbox' "$REPO_ROOT/.claude/plugins" 2>/dev/null
  # Must not find channels references in scripts or .claude (exclude this test file itself)
  ! grep -rn 'channelsEnabled\|--channels\|development-channels' "$REPO_ROOT/scripts" "$REPO_ROOT/.claude" \
      --exclude='inbox-watch-test.sh' 2>/dev/null
}

test_regression_no_inbox_nudge_sh() {
  [ ! -f "$REPO_ROOT/scripts/hooks/inbox-nudge.sh" ]
}

test_regression_no_user_prompt_submit_inbox_entry() {
  ! grep -n 'UserPromptSubmit' "$REPO_ROOT/.claude/settings.json" 2>/dev/null | grep -qi 'inbox'
}

test_regression_no_v2_nudge_phrasing() {
  ! grep -rn 'pending message(s)\. Run /check-inbox to read them\.' "$REPO_ROOT/scripts/hooks/" 2>/dev/null
}

# ────────────────────────────────────────────────────────────────
# Test runner
# ────────────────────────────────────────────────────────────────

# xfail-wrapped tests (require impl scripts to pass)
run_xfail test_boot_sweep_emits_one_line_per_pending
run_xfail test_boot_sweep_empty_inbox_emits_nothing
run_xfail test_line_format_contract
run_xfail test_identity_resolution_chain
run_xfail test_identity_source2_strawberry_agent
run_xfail test_no_identity_exits_cleanly
run_xfail test_unknown_agent_exits_cleanly
run_xfail test_no_inbox_watch_opt_out_suppresses_watcher
run_xfail test_archive_subdir_not_swept_by_phase1
run_xfail test_frontmatter_without_status_never_emits
run_xfail test_status_read_never_emits
run_xfail test_archive_retention_deletes_stale_files
run_xfail test_archive_retention_preserves_fresh_files
run_xfail test_archive_retention_prunes_empty_month_buckets
run_xfail test_archive_cleanup_noop_when_archive_dir_absent
run_xfail test_check_inbox_moves_pending_to_archive_yyyy_mm
run_xfail test_check_inbox_archive_fallback_to_mtime_when_no_timestamp
run_xfail test_bootstrap_emits_json_on_startup
run_xfail test_bootstrap_silent_on_resume
run_xfail test_bootstrap_silent_on_clear
run_xfail test_bootstrap_silent_on_compact
run_xfail test_bootstrap_opt_out_honored
run_xfail test_settings_json_has_bootstrap_entry

# Real regression tests (always green)
run_real test_regression_no_channels_artifacts
run_real test_regression_no_inbox_nudge_sh
run_real test_regression_no_user_prompt_submit_inbox_entry
run_real test_regression_no_v2_nudge_phrasing

printf '\nResults: %d passed, %d failed, %d xfail, %d xpass\n' \
  "$PASS" "$FAIL" "$XFAIL_COUNT" "$XPASS_COUNT"

[ "$FAIL" -eq 0 ] && [ "$XPASS_COUNT" -eq 0 ]
