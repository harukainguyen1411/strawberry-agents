#!/bin/sh
# run-fixture.sh — harness for breakdown-qa-tasks linter fixture tests
#
# Usage: bash tests/fixtures/qa-enforcement/breakdowns/run-fixture.sh <fixture-file> <identity>
#
# Sets STRAWBERRY_AGENT=<identity>, then invokes the breakdown-qa-tasks linter
# against <fixture-file> using its --fixture-path / --staged-path interface.
#
# Example:
#   bash tests/fixtures/qa-enforcement/breakdowns/run-fixture.sh \
#     tests/fixtures/qa-enforcement/breakdowns/a-aphelios-tasks-no-qa-tasks.md \
#     aphelios
#
# Exit code mirrors the linter's exit code (0=accept, 1=reject).

set -e

FIXTURE="${1:-}"
IDENTITY="${2:-}"

if [ -z "$FIXTURE" ] || [ -z "$IDENTITY" ]; then
  printf 'Usage: %s <fixture-file> <identity>\n' "$0" >&2
  exit 1
fi

if [ ! -f "$FIXTURE" ]; then
  printf 'ERROR: fixture file not found: %s\n' "$FIXTURE" >&2
  exit 1
fi

export STRAWBERRY_AGENT="$IDENTITY"

exec bash scripts/hooks/pre-commit-breakdown-qa-tasks.sh \
  --fixture-path "$FIXTURE" \
  --staged-path "plans/proposed/test-fixture.md"
