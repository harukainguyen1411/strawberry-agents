# xfail: D1 — scripts/report-run.sh (plans/approved/2026-04-17-test-dashboard-phase1-tasks.md)
# Bats tests expected to fail until report-run.sh is implemented.
# Run with: bats scripts/__tests__/report-run.xfail.bats

setup() {
  # Minimal mock HTTP listener that immediately closes connections (simulates unreachable service)
  MOCK_PORT=19876
  export INGEST_TOKEN="test-token"
  export DASHBOARD_URL="http://127.0.0.1:${MOCK_PORT}"
  FIXTURE_DIR="$(dirname "$BATS_TEST_FILENAME")/../fixtures"
}

# --- Test 1: unit type times out at 2s on POST ---
@test "unit reporter: POST times out at 2s when service is unreachable" {
  # xfail: report-run.sh not yet implemented
  skip "xfail: D1 not yet implemented"

  # Start a listener that never responds (simulates hung service)
  nc -l "$MOCK_PORT" >/dev/null 2>&1 &
  NC_PID=$!

  start=$(date +%s)
  run bash scripts/report-run.sh "${FIXTURE_DIR}/vitest-sample.json" unit
  end=$(date +%s)
  elapsed=$(( end - start ))

  kill "$NC_PID" 2>/dev/null || true

  # Should exit 0 (fire-and-forget — timeout is soft) and complete within ~3s
  [ "$status" -eq 0 ]
  [ "$elapsed" -le 3 ]
}

# --- Test 2: e2e type soft-fails (exit 0 + stderr warning) when unreachable ---
@test "e2e reporter: exits 0 with stderr warning when service unreachable" {
  # xfail: report-run.sh not yet implemented
  skip "xfail: D1 not yet implemented"

  run bash scripts/report-run.sh "${FIXTURE_DIR}/vitest-sample.json" e2e
  [ "$status" -eq 0 ]
  [[ "$output" =~ "warning" ]] || [[ "$stderr" =~ "warning" ]]
}

# --- Test 3: script POSTs correct body shape to /api/runs ---
@test "report-run.sh: POSTs JSON body with required fields to /api/runs" {
  # xfail: report-run.sh not yet implemented
  skip "xfail: D1 not yet implemented"

  # Start a mock HTTP server that captures the request body
  CAPTURED=$(mktemp)
  # Use nc to accept one connection and record what was sent
  (nc -l "$MOCK_PORT" > "$CAPTURED" 2>/dev/null; echo "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}" ) &
  NC_PID=$!
  sleep 0.1  # give nc time to bind

  run bash scripts/report-run.sh "${FIXTURE_DIR}/vitest-sample.json" unit
  kill "$NC_PID" 2>/dev/null || true

  # Body must contain required top-level fields per ADR §6
  grep -q '"type"' "$CAPTURED"
  grep -q '"git_sha"' "$CAPTURED"
  grep -q '"cases"' "$CAPTURED"
  rm -f "$CAPTURED"
}
