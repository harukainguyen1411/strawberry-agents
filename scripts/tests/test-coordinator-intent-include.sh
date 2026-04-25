#!/usr/bin/env bash
# Structural assertion: coordinator-deliberation-primitive include wiring.
# Plan: plans/approved/personal/2026-04-25-coordinator-deliberation-primitive.md
# Rule 12: lands xfail-first on the branch, before implementation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

INCLUDE_FILE="$REPO_ROOT/.claude/agents/_shared/coordinator-intent-check.md"
EVELYNN_DEF="$REPO_ROOT/.claude/agents/evelynn.md"
SONA_DEF="$REPO_ROOT/.claude/agents/sona.md"

PASS=0

# Check A: include file exists
if [ -f "$INCLUDE_FILE" ]; then
    echo "PASS A: $INCLUDE_FILE exists"
else
    echo "FAIL A: $INCLUDE_FILE does not exist"
    PASS=1
fi

# Check B: include file contains all three required H2 headings
if [ -f "$INCLUDE_FILE" ]; then
    if ! grep -qF '## Intent block' "$INCLUDE_FILE"; then
        echo "FAIL B1: missing '## Intent block' in $INCLUDE_FILE"
        PASS=1
    else
        echo "PASS B1: '## Intent block' present"
    fi

    if ! grep -qF '## "Surgical" is not a license' "$INCLUDE_FILE"; then
        echo "FAIL B2: missing '## \"Surgical\" is not a license' in $INCLUDE_FILE"
        PASS=1
    else
        echo "PASS B2: '## \"Surgical\" is not a license' present"
    fi

    if ! grep -qF '## Altitude selection' "$INCLUDE_FILE"; then
        echo "FAIL B3: missing '## Altitude selection' in $INCLUDE_FILE"
        PASS=1
    else
        echo "PASS B3: '## Altitude selection' present"
    fi
fi

# Check C: both coordinator defs contain the include line
INCLUDE_LINE='<!-- include: _shared/coordinator-intent-check.md -->'

if grep -qF "$INCLUDE_LINE" "$EVELYNN_DEF"; then
    echo "PASS C1: evelynn.md contains include line"
else
    echo "FAIL C1: evelynn.md missing include line"
    PASS=1
fi

if grep -qF "$INCLUDE_LINE" "$SONA_DEF"; then
    echo "PASS C2: sona.md contains include line"
else
    echo "FAIL C2: sona.md missing include line"
    PASS=1
fi

# Check D: sync is idempotent — running sync-shared-rules.sh twice shows "up-to-date"
# on the second pass, confirming inlined content matches the canonical source.
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-shared-rules.sh"
if [ -f "$SYNC_SCRIPT" ]; then
    # First pass: normalize any stale content
    bash "$SYNC_SCRIPT" >/dev/null 2>&1
    # Second pass: verify idempotency — no "synced" lines means nothing changed
    sync_out="$(bash "$SYNC_SCRIPT" 2>&1)"
    if printf '%s\n' "$sync_out" | grep -qE '^sync-shared-rules: synced (evelynn|sona)\.md'; then
        echo "FAIL D: second sync pass still shows changes — inlined content is stale"
        printf '%s\n' "$sync_out" >&2
        PASS=1
    else
        echo "PASS D: sync-shared-rules.sh is idempotent (second pass: up-to-date)"
    fi
else
    echo "FAIL D: $SYNC_SCRIPT not found"
    PASS=1
fi

if [ "$PASS" -eq 0 ]; then
    echo ""
    echo "ALL CHECKS PASSED"
else
    echo ""
    echo "ONE OR MORE CHECKS FAILED"
fi

exit "$PASS"
