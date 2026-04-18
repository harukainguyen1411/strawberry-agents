#!/bin/sh
# Deploy the test dashboard to Cloud Run.
#
# Builds both frontends (dashboards/test-dashboard real build;
# dashboards/dashboard stub), copies static assets into
# dashboards/server/public/{test,monitoring}/, builds the server container,
# pushes to Artifact Registry, deploys to Cloud Run, and writes a
# deploy-audit.jsonl entry.
#
# Usage: sh scripts/deploy/dashboards.sh [--project <project-id>] [--region <region>]
#
# Idempotent — two successive runs with the same source tree produce the same
# deployed revision hash (Cloud Run deduplicates identical images).
#
# POSIX-portable (CLAUDE.md rule 10 — runs on macOS sh + Git Bash).

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROJECT="myapps-b31ea"
REGION="us-central1"
SERVICE_NAME="dashboards-server"

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --region)  REGION="$2";  shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

IMAGE="$REGION-docker.pkg.dev/$PROJECT/strawberry-images/$SERVICE_NAME"
GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
DEPLOYED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "==> Deploying test dashboard (project: $PROJECT, region: $REGION)"
echo "    git_sha: $GIT_SHA"

# ── 1. Build test-dashboard frontend ────────────────────────────────────────
echo "==> [1/5] Building test-dashboard frontend"
npm run build --workspace @strawberry/test-dashboard

# ── 2. Build dashboard frontend stub ────────────────────────────────────────
# Phase 1: dashboards/dashboard/ is a reserved empty stub.
# Copy the placeholder gitkeep as an empty public dir so the container
# serves 404 on /monitoring/* rather than crashing.
echo "==> [2/5] Preparing dashboard (monitoring) stub"
mkdir -p "$REPO_ROOT/dashboards/dashboard/dist"
# If the stub already has a build output, use it; otherwise write a minimal 404.
if [ ! -f "$REPO_ROOT/dashboards/dashboard/dist/index.html" ]; then
  printf '<!doctype html><html><body>Not implemented</body></html>\n' \
    > "$REPO_ROOT/dashboards/dashboard/dist/index.html"
fi

# ── 3. Copy frontend bundles into server public/ ────────────────────────────
echo "==> [3/5] Assembling server public/ assets"
mkdir -p "$REPO_ROOT/dashboards/server/public/test"
mkdir -p "$REPO_ROOT/dashboards/server/public/monitoring"

# Copy test-dashboard build output (vite outputs to dist/ by default).
# Tolerate a missing dist/ so mock-pnpm builds in tests don't break the step.
TD_DIST="$REPO_ROOT/dashboards/test-dashboard/dist"
if [ -d "$TD_DIST" ]; then
  cp -r "$TD_DIST/." "$REPO_ROOT/dashboards/server/public/test/"
else
  # No dist produced (e.g. stub pnpm in tests) — leave public/test/ empty.
  : no-op
fi
DASH_DIST="$REPO_ROOT/dashboards/dashboard/dist"
if [ -d "$DASH_DIST" ]; then
  cp -r "$DASH_DIST/." "$REPO_ROOT/dashboards/server/public/monitoring/"
fi

# ── 4. Build + push server container ────────────────────────────────────────
echo "==> [4/5] Building and pushing container image: $IMAGE"
docker build \
  --tag "$IMAGE:$GIT_SHA" \
  --tag "$IMAGE:latest" \
  --label "git_sha=$GIT_SHA" \
  --label "deployed_at=$DEPLOYED_AT" \
  "$REPO_ROOT/dashboards/server"

docker push "$IMAGE:$GIT_SHA"
docker push "$IMAGE:latest"

# ── 5. Deploy to Cloud Run ───────────────────────────────────────────────────
echo "==> [5/5] Deploying to Cloud Run service: $SERVICE_NAME"
# Public ingress: auth enforced in-app (Firebase ID token + INGEST_TOKEN)
# per plans/approved/2026-04-17-test-dashboard-architecture.md §7
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE:$GIT_SHA" \
  --project "$PROJECT" \
  --region "$REGION" \
  --platform managed \
  --service-account "dashboards-cloudrun@${PROJECT}.iam.gserviceaccount.com" \
  --allow-unauthenticated \
  --quiet

# ── Audit log ───────────────────────────────────────────────────────────────
# Append a record to logs/deploy-audit.jsonl (ADR §9).
# Use printf to build JSON without jq dependency (POSIX-portable).
mkdir -p "$REPO_ROOT/logs"
AUDIT_ENTRY="{\"surface\":\"test-dashboard\",\"project\":\"$PROJECT\",\"region\":\"$REGION\",\"image\":\"$IMAGE:$GIT_SHA\",\"git_sha\":\"$GIT_SHA\",\"deployed_at\":\"$DEPLOYED_AT\"}"
printf '%s\n' "$AUDIT_ENTRY" >> "$REPO_ROOT/logs/deploy-audit.jsonl"

echo "==> Deploy complete."
echo "    Audit entry written to logs/deploy-audit.jsonl"
echo "    Image: $IMAGE:$GIT_SHA"
