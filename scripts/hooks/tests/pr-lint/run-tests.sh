#!/bin/sh
# run-tests.sh — Unit test runner for scripts/ci/pr-lint-check.sh
#
# XFAIL: Before T4 ships the implementation, pr-lint-check.sh exits 2 (stub).
# This runner detects the stub exit code and reports xfail, exiting non-zero.
# After T4 implementation, all four cases should pass and runner exits 0.
#
# Tests:
#   T1 — user-flow path, no marker → expect exit 1 (Rule 16 violation)
#   T2 — infra/docs path, no marker → expect exit 0 (exempt)
#   T3 — UI component path, no marker → expect exit 1 (Rule 16 violation)
#   T4 — user-flow path + QA-Waiver → expect exit 0 (waiver accepted)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINTER="$(cd "$SCRIPT_DIR/../../../.." && pwd)/scripts/ci/pr-lint-check.sh"

pass=0
fail=0
xfail=0

run_case() {
    case_name="$1"
    pr_body="$2"
    changed_files="$3"
    expected_exit="$4"

    actual_exit=0
    PR_BODY="$pr_body" CHANGED_FILES="$changed_files" sh "$LINTER" >/dev/null 2>&1 || actual_exit=$?

    if [ "$actual_exit" = "2" ]; then
        # Stub not-implemented exit — xfail
        echo "XFAIL $case_name (stub not implemented)"
        xfail=$((xfail + 1))
    elif [ "$actual_exit" = "$expected_exit" ]; then
        echo "PASS  $case_name"
        pass=$((pass + 1))
    else
        echo "FAIL  $case_name: expected exit $expected_exit, got $actual_exit"
        fail=$((fail + 1))
    fi
}

# T1: user-flow route path, no marker → expect violation (exit 1)
run_case "T1-user-flow-no-marker" \
    "## Summary\nAdds new auth route" \
    "apps/demo/routes/new-auth.ts" \
    "1"

# T2: infra/docs only, no marker → expect exempt (exit 0)
run_case "T2-infra-docs-exempt" \
    "## Summary\nUpdates deploy script" \
    "scripts/deploy/foo.sh
architecture/notes.md" \
    "0"

# T3: UI component path, no marker → expect violation (exit 1)
run_case "T3-ui-component-no-marker" \
    "## Summary\nAdds Button component" \
    "apps/studio/components/Button.tsx" \
    "1"

# T4: user-flow path + QA-Waiver → expect exempt (exit 0)
run_case "T4-user-flow-with-waiver" \
    "## Summary\nAdds new form
QA-Waiver: design still in flux" \
    "apps/demo/forms/contact.tsx" \
    "0"

echo ""
echo "Results: $pass passed, $fail failed, $xfail xfail"

if [ "$xfail" -gt 0 ]; then
    echo "XFAIL: pr-lint-check.sh stub not yet implemented — expected before T4 ships"
    exit 1
fi

if [ "$fail" -gt 0 ]; then
    exit 1
fi

exit 0
