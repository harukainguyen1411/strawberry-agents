#!/usr/bin/env bash
# Structural assertion: coordinator-deliberation-primitive include wiring.
# Fails (exit 1) until T2+T3 land.
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
if [ "$PASS" -eq 0 ] || [ -f "$INCLUDE_FILE" ]; then
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

if [ "$PASS" -eq 0 ]; then
    echo ""
    echo "ALL CHECKS PASSED"
else
    echo ""
    echo "ONE OR MORE CHECKS FAILED"
fi

exit "$PASS"
