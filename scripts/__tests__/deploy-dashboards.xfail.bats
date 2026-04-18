#!/usr/bin/env bats
# xfail: tests for scripts/deploy/dashboards.sh idempotency and audit log emission.
# These tests use a mock gcloud/gsutil/docker on $PATH and will pass once
# dashboards.sh is implemented.
#
# xfail: all tests below are expected to fail until the implementation lands.
# Refs: plans/approved/2026-04-17-test-dashboard-phase1-tasks.md §I1

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/deploy/dashboards.sh"
MOCK_DIR="$(mktemp -d)"
AUDIT_LOG="$REPO_ROOT/logs/deploy-audit.jsonl"

setup() {
  # Stub gcloud — records calls, returns success
  cat > "$MOCK_DIR/gcloud" <<'EOF'
#!/usr/bin/env bash
echo "gcloud $*" >> "$MOCK_DIR/gcloud.calls"
# For "run deploy" return a fixed revision
if [[ "$*" == *"run deploy"* ]]; then
  echo "Deploying container to Cloud Run service [dashboards-server]..."
  echo "Service [dashboards-server] revision [dashboards-server-00001-abc] has been deployed"
fi
exit 0
EOF
  chmod +x "$MOCK_DIR/gcloud"

  # Stub docker
  cat > "$MOCK_DIR/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$MOCK_DIR/docker.calls"
exit 0
EOF
  chmod +x "$MOCK_DIR/docker"

  # Stub pnpm
  cat > "$MOCK_DIR/pnpm" <<'EOF'
#!/usr/bin/env bash
echo "pnpm $*" >> "$MOCK_DIR/pnpm.calls"
exit 0
EOF
  chmod +x "$MOCK_DIR/pnpm"

  export PATH="$MOCK_DIR:$PATH"
  export MOCK_DIR
  # Remove audit log so we start clean
  rm -f "$AUDIT_LOG"
}

teardown() {
  rm -rf "$MOCK_DIR"
  rm -f "$AUDIT_LOG"
}

@test "script exists and is executable" {
  # xfail: will fail until dashboards.sh is created
  [ -x "$SCRIPT" ]
}

@test "runs to completion with --project flag" {
  # xfail: will fail until dashboards.sh is created
  run bash "$SCRIPT" --project myapps-b31ea
  [ "$status" -eq 0 ]
}

@test "emits deploy-audit.jsonl entry with surface=test-dashboard" {
  # xfail: will fail until dashboards.sh is created
  bash "$SCRIPT" --project myapps-b31ea
  [ -f "$AUDIT_LOG" ]
  grep -q '"surface":"test-dashboard"' "$AUDIT_LOG"
}

@test "audit entry contains project and git_sha fields" {
  # xfail: will fail until dashboards.sh is created
  bash "$SCRIPT" --project myapps-b31ea
  grep -q '"project":"myapps-b31ea"' "$AUDIT_LOG"
  grep -q '"git_sha"' "$AUDIT_LOG"
}

@test "idempotent — two runs produce same Cloud Run revision" {
  # xfail: will fail until dashboards.sh is created
  bash "$SCRIPT" --project myapps-b31ea
  rev1=$(grep "run deploy" "$MOCK_DIR/gcloud.calls" | tail -1)
  bash "$SCRIPT" --project myapps-b31ea
  rev2=$(grep "run deploy" "$MOCK_DIR/gcloud.calls" | tail -1)
  [ "$rev1" = "$rev2" ]
}

@test "builds test-dashboard frontend before server container" {
  # xfail: will fail until dashboards.sh is created
  bash "$SCRIPT" --project myapps-b31ea
  pnpm_calls=$(cat "$MOCK_DIR/pnpm.calls")
  # test-dashboard build must appear before docker build
  td_line=$(grep -n "test-dashboard" "$MOCK_DIR/pnpm.calls" | head -1 | cut -d: -f1)
  docker_line=$(grep -n "build" "$MOCK_DIR/docker.calls" | head -1 | cut -d: -f1)
  [ -n "$td_line" ]
  [ -n "$docker_line" ]
  [ "$td_line" -lt "$docker_line" ]
}
