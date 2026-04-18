#!/bin/sh
# report-run.sh <reporter-json-path> <type>
#
# Normalises a framework JSON test report into the POST /api/runs ingestion shape,
# POSTs it to the dashboard, and uploads any declared artifacts.
#
# Required env:
#   INGEST_TOKEN    — bearer token for ingestion endpoints
#   DASHBOARD_URL   — base URL e.g. https://dashboard.example.com (no trailing slash)
#
# Optional env:
#   GIT_SHA         — overrides auto-detected git SHA
#   GIT_REF         — overrides auto-detected branch/tag
#   ACTOR           — overrides auto-detected actor (defaults to git user.email)
#
# Per ADR §13:
#   unit type   — 2s POST timeout, fire-and-forget (exit 0 even on failure)
#   e2e type    — soft-fail: exit 0 + stderr warning on POST failure
#   other types — exit non-zero on POST failure

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── argument validation ────────────────────────────────────────────────────────
if [ $# -lt 2 ]; then
  echo "Usage: $0 <reporter-json-path> <type>" >&2
  echo "  type: unit | xfail | regression | e2e | qa | smoke" >&2
  exit 1
fi

REPORTER_JSON="$1"
RUN_TYPE="$2"

if [ ! -f "$REPORTER_JSON" ]; then
  echo "report-run.sh: reporter JSON not found: $REPORTER_JSON" >&2
  exit 1
fi

case "$RUN_TYPE" in
  unit|xfail|regression|e2e|qa|smoke) ;;
  *)
    echo "report-run.sh: unknown type '$RUN_TYPE'" >&2
    exit 1
    ;;
esac

# ── env checks ─────────────────────────────────────────────────────────────────
if [ -z "${INGEST_TOKEN:-}" ]; then
  echo "report-run.sh: INGEST_TOKEN is required" >&2
  exit 1
fi
if [ -z "${DASHBOARD_URL:-}" ]; then
  echo "report-run.sh: DASHBOARD_URL is required" >&2
  exit 1
fi

# ── git context ────────────────────────────────────────────────────────────────
GIT_SHA="${GIT_SHA:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")}"
GIT_REF="${GIT_REF:-$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo "unknown")}"
ACTOR="${ACTOR:-$(git -C "$REPO_ROOT" config user.email 2>/dev/null || echo "unknown")}"

# ── detect environment ─────────────────────────────────────────────────────────
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  ENVIRONMENT="ci"
elif [ -n "${DEPLOY_ENV:-}" ]; then
  ENVIRONMENT="$DEPLOY_ENV"
else
  ENVIRONMENT="local"
fi

# ── normalise Vitest/Jest JSON → ingestion shape ───────────────────────────────
# Requires: node (available on macOS bash 3.2 + Git Bash environments)
BODY=$(node - "$REPORTER_JSON" "$RUN_TYPE" "$GIT_SHA" "$GIT_REF" "$ACTOR" "$ENVIRONMENT" <<'NODEJS'
const fs = require("fs");
const path = require("path");

const [,, reporterJson, type, gitSha, gitRef, actor, environment] = process.argv;
const report = JSON.parse(fs.readFileSync(reporterJson, "utf8"));

const now = new Date().toISOString();
const startedAt = report.startTime ? new Date(report.startTime).toISOString() : now;
const finishedAt = report.endTime ? new Date(report.endTime).toISOString() : now;

let total = 0, pass = 0, fail = 0, skipped = 0, xfailCount = 0;
const cases = [];

const suites = report.testResults || report.results || [];
for (const suite of suites) {
  const suiteName = suite.testFilePath || suite.name || "unknown";
  const assertions = suite.assertionResults || suite.tests || suite.specs || [];
  for (const t of assertions) {
    total++;
    const status = t.status === "passed" ? "pass"
      : t.status === "failed" ? "fail"
      : t.status === "skipped" || t.status === "pending" ? "skipped"
      : t.status === "todo" ? "skipped"
      : t.status;
    if (status === "pass") pass++;
    else if (status === "fail") fail++;
    else skipped++;

    const failMsg = Array.isArray(t.failureMessages) && t.failureMessages[0]
      ? t.failureMessages[0].slice(0, 8192)
      : null;

    cases.push({
      id: `case_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      run_id: "",
      suite: suiteName,
      name: t.fullName || t.title || t.name || "unnamed",
      status,
      duration_ms: t.duration || 0,
      failure_message: failMsg,
      failure_stack: null,
      artifacts: [],
    });
  }
}

const runStatus = fail > 0 ? "fail" : "pass";

const run = {
  type,
  environment,
  project: process.env.FIREBASE_PROJECT_ID || null,
  git_sha: gitSha,
  git_ref: gitRef,
  version: process.env.VERSION || null,
  actor,
  started_at: startedAt,
  finished_at: finishedAt,
  status: runStatus,
  counts: { total, pass, fail, skipped, xfail: xfailCount },
  trigger: {
    source: environment === "ci" ? "gh-actions"
      : environment === "local" ? "pre-commit"
      : "manual",
    workflow: process.env.GITHUB_WORKFLOW || null,
    pr_number: process.env.GITHUB_PR_NUMBER ? Number(process.env.GITHUB_PR_NUMBER) : null,
  },
  metadata: {},
};

process.stdout.write(JSON.stringify({ run, cases }));
NODEJS
)

# ── POST to /api/runs ──────────────────────────────────────────────────────────
POST_URL="${DASHBOARD_URL}/api/runs"

_do_post() {
  curl -sf \
    -X POST \
    -H "Authorization: Bearer ${INGEST_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$POST_URL"
}

if [ "$RUN_TYPE" = "unit" ]; then
  # Fire-and-forget: 2s timeout, always exit 0
  RESPONSE=$(curl -sf \
    --max-time 2 \
    -X POST \
    -H "Authorization: Bearer ${INGEST_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$POST_URL" 2>/dev/null) || {
    echo "report-run.sh: warning: dashboard unreachable (unit fire-and-forget, ignoring)" >&2
    exit 0
  }
elif [ "$RUN_TYPE" = "e2e" ]; then
  # Soft-fail: exit 0 + stderr warning on failure
  RESPONSE=$(_do_post 2>/dev/null) || {
    echo "report-run.sh: warning: failed to report e2e run to dashboard (soft-fail)" >&2
    exit 0
  }
else
  # All other types: hard-fail on POST error
  RESPONSE=$(_do_post)
fi

# ── extract run_id and upload URLs ────────────────────────────────────────────
RUN_ID=$(node -e "process.stdout.write(JSON.parse(process.argv[1]).run_id)" "$RESPONSE" 2>/dev/null || echo "")
if [ -z "$RUN_ID" ]; then
  echo "report-run.sh: warning: could not parse run_id from response" >&2
  exit 0
fi

# ── upload artifacts (parallel) ───────────────────────────────────────────────
# Extract upload URLs map: { local_ref: signed_url }
UPLOAD_URLS=$(node -e "
  const r = JSON.parse(process.argv[1]);
  const urls = r.artifact_upload_urls || {};
  for (const [ref, url] of Object.entries(urls)) {
    process.stdout.write(ref + '\t' + url + '\n');
  }
" "$RESPONSE" 2>/dev/null || true)

if [ -n "$UPLOAD_URLS" ]; then
  echo "$UPLOAD_URLS" | while IFS="	" read -r local_ref signed_url; do
    artifact_file="${local_ref}"
    if [ -f "$artifact_file" ]; then
      curl -sf -X PUT \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@${artifact_file}" \
        "$signed_url" >/dev/null 2>&1 &
    fi
  done
  wait
fi

# ── finalize run ──────────────────────────────────────────────────────────────
curl -sf \
  -X POST \
  -H "Authorization: Bearer ${INGEST_TOKEN}" \
  "${DASHBOARD_URL}/api/runs/${RUN_ID}/finalize" >/dev/null 2>&1 || {
  echo "report-run.sh: warning: finalize call failed for run ${RUN_ID}" >&2
}

exit 0
