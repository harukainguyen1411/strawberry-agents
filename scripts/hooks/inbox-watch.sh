#!/usr/bin/env bash
# inbox-watch.sh — Monitor-target watcher for coordinator inbox delivery.
#
# Implements plans/in-progress/2026-04-20-strawberry-inbox-channel.md §3.2
#
# Usage (via Monitor tool):
#   bash scripts/hooks/inbox-watch.sh
#
# One-shot mode (for unit tests):
#   INBOX_WATCH_ONESHOT=1 bash scripts/hooks/inbox-watch.sh
#
# Identity resolution (in order):
#   1. CLAUDE_AGENT_NAME env var
#   2. STRAWBERRY_AGENT env var
#   3. .claude/settings.json .agent field (case-insensitive)
#   4. If none resolves, exit 0 silently.
#
# Opt-out: touch .no-inbox-watch at repo root → exit 0 silently (total).
#
# Output contract (stdout only):
#   INBOX: <filename> — from <sender> — <priority>
#   (em-dash U+2014, one line per pending message)
#   No other stdout output is ever emitted (noisy-monitor guard).
#
# POSIX-portable bash (Rule 10). set -eu only (no pipefail: POSIX).
set -eu

# ────────────────────────────────────────────────────────────────
# Resolve repo root
# ────────────────────────────────────────────────────────────────

if [ -n "${REPO_ROOT:-}" ]; then
  REPO="$REPO_ROOT"
else
  REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO="$(pwd)"
fi

# ────────────────────────────────────────────────────────────────
# Opt-out check (before anything else, including Phase 0)
# ────────────────────────────────────────────────────────────────

if [ -f "$REPO/.no-inbox-watch" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Coordinator identity resolution
# ────────────────────────────────────────────────────────────────

coord=""

if [ -n "${CLAUDE_AGENT_NAME:-}" ]; then
  coord="$(printf '%s' "$CLAUDE_AGENT_NAME" | tr '[:upper:]' '[:lower:]')"
elif [ -n "${STRAWBERRY_AGENT:-}" ]; then
  coord="$(printf '%s' "$STRAWBERRY_AGENT" | tr '[:upper:]' '[:lower:]')"
else
  # Try .claude/settings.json .agent field
  settings="$REPO/.claude/settings.json"
  if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
    raw="$(jq -r '.agent // empty' "$settings" 2>/dev/null || true)"
    if [ -n "$raw" ]; then
      coord="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    fi
  fi
fi

# No identity resolved — exit cleanly (no target inbox)
if [ -z "$coord" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Validate agent directory exists
# ────────────────────────────────────────────────────────────────

AGENT_DIR="$REPO/agents/$coord"
INBOX_DIR="$AGENT_DIR/inbox"

if [ ! -d "$AGENT_DIR" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Phase 0: archive cleanup (one-shot, per session boot)
# Delete archived files older than 7 days; prune empty month buckets.
# 2>/dev/null suppresses noise when archive dir does not exist yet.
# ────────────────────────────────────────────────────────────────

find "$INBOX_DIR/archive" -type f -name '*.md' -mtime +7 -delete 2>/dev/null || true
find "$INBOX_DIR/archive" -type d -empty -delete 2>/dev/null || true

# ────────────────────────────────────────────────────────────────
# Phase 1: boot-time pending sweep
# Flat glob on inbox/*.md — archive/ subdirs are not matched by
# the pattern because they sit at a deeper level.
# ────────────────────────────────────────────────────────────────

if [ -d "$INBOX_DIR" ]; then
  for msg_file in "$INBOX_DIR"/*.md; do
    # Glob may not match if inbox is empty
    [ -f "$msg_file" ] || continue
    # Only emit pending messages
    if grep -q 'status: pending' "$msg_file" 2>/dev/null; then
      filename="$(basename "$msg_file")"
      sender="$(grep '^from:' "$msg_file" | head -1 | sed 's/^from: *//' | tr -d '[:space:]')"
      priority="$(grep '^priority:' "$msg_file" | head -1 | sed 's/^priority: *//' | tr -d '[:space:]')"
      # Emit one stdout line per pending message (em-dash U+2014)
      printf 'INBOX: %s \xe2\x80\x94 from %s \xe2\x80\x94 %s\n' "$filename" "$sender" "$priority"
    fi
  done
fi

# One-shot mode: Phase 0 + Phase 1 only (used by tests)
if [ "${INBOX_WATCH_ONESHOT:-}" = "1" ]; then
  exit 0
fi

# ────────────────────────────────────────────────────────────────
# Phase 2: live watch
# Detection order:
#   1. fswatch (macOS/Homebrew)
#   2. inotifywait (Linux)
#   3. Poll fallback (3 s)
# Only emit when re-reading the new file confirms status: pending.
# ────────────────────────────────────────────────────────────────

emit_if_pending() {
  local msg_file="$1"
  [ -f "$msg_file" ] || return 0
  if grep -q 'status: pending' "$msg_file" 2>/dev/null; then
    filename="$(basename "$msg_file")"
    sender="$(grep '^from:' "$msg_file" | head -1 | sed 's/^from: *//' | tr -d '[:space:]')"
    priority="$(grep '^priority:' "$msg_file" | head -1 | sed 's/^priority: *//' | tr -d '[:space:]')"
    printf 'INBOX: %s \xe2\x80\x94 from %s \xe2\x80\x94 %s\n' "$filename" "$sender" "$priority"
  fi
}

if command -v fswatch >/dev/null 2>&1; then
  # fswatch: macOS default once Homebrew-installed
  # Watch inbox directory for created/moved-in events (non-recursive via flat dir)
  fswatch -x --event Created --event MovedTo "$INBOX_DIR" 2>/dev/null | while IFS= read -r event_line; do
    # Extract the file path from the event line (first token)
    msg_file="$(printf '%s' "$event_line" | awk '{print $1}')"
    # Only process .md files directly in inbox/ (not in subdirs)
    case "$msg_file" in
      "$INBOX_DIR"/*.md) emit_if_pending "$msg_file" ;;
    esac
  done
elif command -v inotifywait >/dev/null 2>&1; then
  # inotifywait: Linux
  inotifywait -m -e create -e moved_to --format '%f' "$INBOX_DIR" 2>/dev/null | while IFS= read -r filename; do
    case "$filename" in
      *.md) emit_if_pending "$INBOX_DIR/$filename" ;;
    esac
  done
else
  # Poll fallback: 3 s cadence
  seen_files=""
  # Seed seen_files with existing files (already swept in Phase 1)
  if [ -d "$INBOX_DIR" ]; then
    for f in "$INBOX_DIR"/*.md; do
      [ -f "$f" ] || continue
      seen_files="$seen_files|$(basename "$f")|"
    done
  fi
  while sleep 3; do
    if [ -d "$INBOX_DIR" ]; then
      for f in "$INBOX_DIR"/*.md; do
        [ -f "$f" ] || continue
        fname="$(basename "$f")"
        case "$seen_files" in
          *"|$fname|"*) ;;
          *)
            seen_files="$seen_files|$fname|"
            emit_if_pending "$f"
            ;;
        esac
      done
    fi
  done
fi
