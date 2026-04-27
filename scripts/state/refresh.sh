#!/usr/bin/env bash
# scripts/state/refresh.sh — dispatcher for per-projection refresh scripts
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T4b
#
# Usage: refresh.sh <db_path> --all
#        refresh.sh <db_path> --prs
#        refresh.sh <db_path> --plans
#        refresh.sh <db_path> --projects
#        refresh.sh <db_path> --inbox
#        refresh.sh <db_path> --feedback
#
# Also consumes sentinel files at ~/.strawberry-state/refresh-pending/<projection>
# and refreshes those projections on --all.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PENDING_DIR="${STRAWBERRY_STATE_DIR:-$HOME/.strawberry-state}/refresh-pending"

DB_PATH="${1:-${STRAWBERRY_STATE_DB:-$HOME/.strawberry-state/state.db}}"
MODE="${2:?refresh.sh: mode required as \$2 (--all or --<projection>)}"

_consume_sentinels() {
    [ -d "$PENDING_DIR" ] || return 0
    for sentinel in "$PENDING_DIR"/*; do
        [ -f "$sentinel" ] || continue
        proj="$(basename "$sentinel")"
        case "$proj" in
            prs_index)    bash "$SCRIPT_DIR/refresh-prs.sh"      "$DB_PATH" ;;
            plans_index)  bash "$SCRIPT_DIR/refresh-plans.sh"    "$DB_PATH" ;;
            projects_index) bash "$SCRIPT_DIR/refresh-projects.sh" "$DB_PATH" ;;
            inbox_index)  bash "$SCRIPT_DIR/refresh-inbox.sh"    "$DB_PATH" ;;
            feedback_index) bash "$SCRIPT_DIR/refresh-feedback.sh" "$DB_PATH" ;;
        esac
        rm -f "$sentinel"
    done
}

case "$MODE" in
    --all)
        _consume_sentinels
        bash "$SCRIPT_DIR/refresh-prs.sh"      "$DB_PATH"
        bash "$SCRIPT_DIR/refresh-plans.sh"    "$DB_PATH"
        bash "$SCRIPT_DIR/refresh-projects.sh" "$DB_PATH"
        bash "$SCRIPT_DIR/refresh-inbox.sh"    "$DB_PATH"
        bash "$SCRIPT_DIR/refresh-feedback.sh" "$DB_PATH"
        ;;
    --prs)      bash "$SCRIPT_DIR/refresh-prs.sh"      "$DB_PATH" ;;
    --plans)    bash "$SCRIPT_DIR/refresh-plans.sh"    "$DB_PATH" ;;
    --projects) bash "$SCRIPT_DIR/refresh-projects.sh" "$DB_PATH" ;;
    --inbox)    bash "$SCRIPT_DIR/refresh-inbox.sh"    "$DB_PATH" ;;
    --feedback) bash "$SCRIPT_DIR/refresh-feedback.sh" "$DB_PATH" ;;
    *)
        printf 'refresh.sh: unknown mode "%s"\n' "$MODE" >&2
        printf 'Usage: refresh.sh <db_path> --all|--prs|--plans|--projects|--inbox|--feedback\n' >&2
        exit 1
        ;;
esac
