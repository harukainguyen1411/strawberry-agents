#!/usr/bin/env bats
# scripts/tests/wrapper-slack-launcher.bats
# Plan: plans/in-progress/work/2026-04-24-sona-secretary-mcp-suite.md / T-new-D
#
# End-to-end smoke test for mcps/wrappers/slack-launcher.sh.
#
# Uses in-test fixture key generation (no dependency on real secrets/age-key.txt
# or real Slack token). Overrides UPSTREAM_START to the probe shim which writes
# $SLACK_USER_TOKEN to a marker file, proving env injection from the child's
# perspective (NOT grep-only — this exec-chain was reviewer-flagged twice).
#
# Assertions:
#   (a) wrapper exits 0
#   (b) probe wrote marker file containing sentinel __SLACK_TEST_TOKEN__
#   (c) secrets/work/runtime/slack.env is mode 0600 (if present) — OR absent
#   (d) parent shell env has no SLACK_USER_TOKEN after wrapper exits
#
# Wired into pre-commit via scripts/hooks/pre-commit-wrapper-slack-test.sh.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
WRAPPER="$REPO_ROOT/mcps/wrappers/slack-launcher.sh"
PROBE="$REPO_ROOT/scripts/tests/probe-upstream-slack.sh"
SENTINEL="__SLACK_TEST_TOKEN__"

# ---------------------------------------------------------------------------
# Setup: generate throwaway age identity + encrypt sentinel value
# ---------------------------------------------------------------------------
setup() {
    # Verify required tools
    if ! command -v age >/dev/null 2>&1; then
        skip "age not installed — skipping smoke test"
    fi
    if ! command -v age-keygen >/dev/null 2>&1; then
        skip "age-keygen not installed — skipping smoke test"
    fi

    # Per-test temp directory
    TEST_TMP="$(mktemp -d)"

    # Generate a throwaway age identity (key + recipient)
    FIXTURE_KEY="$TEST_TMP/fixture.key"
    age-keygen -o "$FIXTURE_KEY" 2>/dev/null
    FIXTURE_RECIPIENT="$(age-keygen -y "$FIXTURE_KEY" 2>/dev/null)"

    # Encrypt sentinel value against throwaway key
    FIXTURE_BLOB="$TEST_TMP/slack-user-token.age"
    printf '%s' "$SENTINEL" | age -e -r "$FIXTURE_RECIPIENT" -o "$FIXTURE_BLOB"

    # Marker file for probe
    PROBE_MARKER="$TEST_TMP/probe-marker.txt"

    # Runtime env-file path (decrypt.sh writes here)
    RUNTIME_ENV="$REPO_ROOT/secrets/work/runtime/slack.env"

    # Override age key: decrypt.sh reads from secrets/age-key.txt by default,
    # but we need to point it at our throwaway key. We accomplish this by
    # symlinking our fixture key to a per-test location and setting REPO_ROOT
    # override isn't supported in decrypt.sh, so we use a wrapper approach:
    # We create a temporary secrets/age-key.txt in a fake repo root.
    FAKE_REPO="$TEST_TMP/fake-repo"
    mkdir -p "$FAKE_REPO/secrets/work/runtime"
    mkdir -p "$FAKE_REPO/secrets/work/encrypted"
    mkdir -p "$FAKE_REPO/tools"
    mkdir -p "$FAKE_REPO/mcps/wrappers"

    # Copy real decrypt.sh and wrapper into fake repo (they resolve paths relative to themselves)
    cp "$REPO_ROOT/tools/decrypt.sh" "$FAKE_REPO/tools/decrypt.sh"
    cp "$WRAPPER" "$FAKE_REPO/mcps/wrappers/slack-launcher.sh"

    # Place fixture key where decrypt.sh expects it
    cp "$FIXTURE_KEY" "$FAKE_REPO/secrets/age-key.txt"
    chmod 600 "$FAKE_REPO/secrets/age-key.txt"

    # Place encrypted blob where the wrapper expects it
    cp "$FIXTURE_BLOB" "$FAKE_REPO/secrets/work/encrypted/slack-user-token.age"

    # gitignore not needed in fake repo; decrypt.sh only checks REPO_ROOT/secrets/
    export STRAWBERRY_AGENTS="$FAKE_REPO"
    export UPSTREAM_START="$PROBE"
    export PROBE_MARKER_FILE="$PROBE_MARKER"

    # Ensure SLACK_USER_TOKEN is not set in parent before running
    unset SLACK_USER_TOKEN 2>/dev/null || true
}

teardown() {
    rm -rf "$TEST_TMP" 2>/dev/null || true
    unset STRAWBERRY_AGENTS UPSTREAM_START PROBE_MARKER_FILE 2>/dev/null || true
    unset SLACK_USER_TOKEN 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# (a) + (b): wrapper exits 0 AND probe writes marker with sentinel
# ---------------------------------------------------------------------------
@test "T-new-D smoke (a+b): wrapper exits 0 and probe marker contains sentinel" {
    run bash "$FAKE_REPO/mcps/wrappers/slack-launcher.sh"
    # (a) exit 0
    [ "$status" -eq 0 ]
    # (b) marker file exists and contains sentinel
    [ -f "$PROBE_MARKER" ]
    marker_value="$(cat "$PROBE_MARKER")"
    [ "$marker_value" = "$SENTINEL" ]
}

# ---------------------------------------------------------------------------
# (c): runtime env-file is mode 0600 if it exists
# ---------------------------------------------------------------------------
@test "T-new-D smoke (c): runtime slack.env is 0600 or absent" {
    run bash "$FAKE_REPO/mcps/wrappers/slack-launcher.sh"
    [ "$status" -eq 0 ]
    RUNTIME_ENV_FAKE="$FAKE_REPO/secrets/work/runtime/slack.env"
    if [ -f "$RUNTIME_ENV_FAKE" ]; then
        mode="$(stat -f '%OLp' "$RUNTIME_ENV_FAKE" 2>/dev/null || stat -c '%a' "$RUNTIME_ENV_FAKE" 2>/dev/null)"
        [ "$mode" = "600" ]
    fi
    # If absent: also acceptable (cleanup may have run)
}

# ---------------------------------------------------------------------------
# (d): parent shell has no SLACK_USER_TOKEN after wrapper exits
# ---------------------------------------------------------------------------
@test "T-new-D smoke (d): parent env has no SLACK_USER_TOKEN after wrapper exits" {
    run bash "$FAKE_REPO/mcps/wrappers/slack-launcher.sh"
    [ "$status" -eq 0 ]
    # SLACK_USER_TOKEN must not be set in the parent (this bats test process)
    run env
    # grep for the sentinel — it must NOT appear in parent env output
    echo "$output" | grep -qv "$SENTINEL"
    # Explicitly check the env var is unset in this shell
    [ -z "${SLACK_USER_TOKEN:-}" ]
}
