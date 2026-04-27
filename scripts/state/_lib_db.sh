#!/usr/bin/env bash
# scripts/state/_lib_db.sh — POSIX-portable SQLite helper library
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D6 §T3b
#
# Exposes four functions:
#   db_open <path>                       — apply D6 pragmas; create schema_migrations table
#   db_write_tx <db_path> <sql>          — BEGIN IMMEDIATE + 3-retry + 250ms backoff
#   db_read <db_path> <sql>              — read-only passthrough
#   db_apply_migrations <db_path> <dir>  — lex-ordered, idempotent migration runner
#
# Source this file; do not execute it directly.
# All functions are exported so forked subshells inherit them (concurrent-write tests).

_DB_BUSY_TIMEOUT=5000
_DB_MAX_RETRIES=3
_DB_BACKOFF_MS=250

db_open() {
    local db_path="$1"
    if [ -z "$db_path" ]; then
        printf '[_lib_db] db_open: db_path is required\n' >&2
        return 1
    fi

    # Apply D6 pragmas. journal_mode=WAL persists in the DB header once set;
    # busy_timeout and synchronous are per-connection, so we emit them on every
    # db_open call to guarantee they are active for the current process.
    sqlite3 "$db_path" \
        "PRAGMA journal_mode=WAL; PRAGMA busy_timeout=${_DB_BUSY_TIMEOUT}; PRAGMA synchronous=NORMAL;" \
        > /dev/null

    # schema_migrations tracking table — created here so it exists before
    # db_apply_migrations is called. Using IF NOT EXISTS so db_open is safe
    # to call multiple times on the same DB.
    sqlite3 "$db_path" \
        "CREATE TABLE IF NOT EXISTS schema_migrations (
           version TEXT PRIMARY KEY,
           applied_at TEXT NOT NULL DEFAULT (datetime('now'))
         );" \
        > /dev/null
}

db_write_tx() {
    local db_path="$1"
    local sql="$2"
    if [ -z "$db_path" ] || [ -z "$sql" ]; then
        printf '[_lib_db] db_write_tx: db_path and sql are required\n' >&2
        return 1
    fi

    local attempt=1
    local result=0
    while [ "$attempt" -le "$_DB_MAX_RETRIES" ]; do
        # BEGIN IMMEDIATE acquires the RESERVED lock up-front, so we fail fast
        # instead of getting SQLITE_BUSY mid-transaction (D6 rationale).
        if sqlite3 "$db_path" \
            "PRAGMA busy_timeout=${_DB_BUSY_TIMEOUT}; PRAGMA synchronous=NORMAL; BEGIN IMMEDIATE; ${sql}; COMMIT;" \
            > /dev/null 2>&1; then
            return 0
        fi

        result=$?
        if [ "$attempt" -lt "$_DB_MAX_RETRIES" ]; then
            # 250ms backoff — sleep accepts fractional seconds on macOS and
            # GNU coreutils; on minimal POSIX shells use perl as fallback.
            sleep 0.25 2>/dev/null || perl -e 'select(undef,undef,undef,0.25)' 2>/dev/null || true
        fi
        attempt=$((attempt + 1))
    done

    printf '[_lib_db] db_write_tx: SQLITE_BUSY after %d retries — hard failure\n' "$_DB_MAX_RETRIES" >&2
    return "$result"
}

db_read() {
    local db_path="$1"
    local sql="$2"
    if [ -z "$db_path" ] || [ -z "$sql" ]; then
        printf '[_lib_db] db_read: db_path and sql are required\n' >&2
        return 1
    fi

    sqlite3 \
        -cmd ".output /dev/null" \
        -cmd "PRAGMA busy_timeout=${_DB_BUSY_TIMEOUT};" \
        -cmd "PRAGMA synchronous=NORMAL;" \
        -cmd ".output stdout" \
        "$db_path" "$sql"
}

db_apply_migrations() {
    local db_path="$1"
    local migrations_dir="$2"
    if [ -z "$db_path" ] || [ -z "$migrations_dir" ]; then
        printf '[_lib_db] db_apply_migrations: db_path and migrations_dir are required\n' >&2
        return 1
    fi
    if [ ! -d "$migrations_dir" ]; then
        printf '[_lib_db] db_apply_migrations: directory not found: %s\n' "$migrations_dir" >&2
        return 1
    fi

    # Ensure D6 pragmas + schema_migrations table exist before we iterate.
    db_open "$db_path" || return 1

    # Collect .sql files in lexicographic order (POSIX-portable glob expansion).
    local migration_file version already_applied sql_body
    for migration_file in "$migrations_dir"/*.sql; do
        [ -f "$migration_file" ] || continue

        version="$(basename "$migration_file")"

        # Skip if already recorded in schema_migrations.
        already_applied=$(sqlite3 "$db_path" \
            "SELECT COUNT(*) FROM schema_migrations WHERE version='${version}';" 2>/dev/null || echo 0)
        if [ "$already_applied" -gt 0 ]; then
            continue
        fi

        # Apply the migration file, then record it as applied. Both steps inside
        # a single BEGIN IMMEDIATE transaction so a crash between them leaves the
        # DB consistent (either both land or neither does).
        sql_body="$(cat "$migration_file")"
        if ! sqlite3 "$db_path" \
            "PRAGMA busy_timeout=${_DB_BUSY_TIMEOUT};
             BEGIN IMMEDIATE;
             ${sql_body}
             INSERT INTO schema_migrations (version) VALUES ('${version}');
             COMMIT;" \
            > /dev/null 2>&1; then
            printf '[_lib_db] db_apply_migrations: failed applying %s\n' "$version" >&2
            return 1
        fi
    done
}

# Export all four functions so forked subshells (concurrent-writer tests) inherit them.
export -f db_open
export -f db_write_tx
export -f db_read
export -f db_apply_migrations
