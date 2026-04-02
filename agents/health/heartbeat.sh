#!/bin/bash
# Write a heartbeat file for an agent.
# Usage: bash heartbeat.sh <agent_name> [platform]

AGENT="${1:?Usage: heartbeat.sh <agent_name> [platform]}"
PLATFORM="${2:-cli}"
HEALTH_DIR="$(cd "$(dirname "$0")" && pwd)"

cat > "${HEALTH_DIR}/${AGENT}.json" <<HEARTBEAT
{"agent":"${AGENT}","last_seen":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","platform":"${PLATFORM}","status":"active"}
HEARTBEAT
