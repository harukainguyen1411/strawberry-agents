#!/bin/bash
# Write a heartbeat for an agent to both the individual file and the registry.
# Usage: bash heartbeat.sh <agent_name> [platform] [status] [current_task]

AGENT="${1:?Usage: heartbeat.sh <agent_name> [platform] [status] [current_task]}"
PLATFORM="${2:-cli}"
STATUS="${3:-idle}"
TASK="${4:-null}"
HEALTH_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY="${HEALTH_DIR}/registry.json"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S)"

# Individual heartbeat file
cat > "${HEALTH_DIR}/${AGENT}.json" <<HEARTBEAT
{"agent":"${AGENT}","last_seen":"${TIMESTAMP}Z","platform":"${PLATFORM}","status":"${STATUS}"}
HEARTBEAT

# Update registry
if [ ! -f "${REGISTRY}" ]; then
    echo '{}' > "${REGISTRY}"
fi

if command -v jq >/dev/null 2>&1; then
    jq --arg name "${AGENT}" --arg status "${STATUS}" --arg ts "${TIMESTAMP}" \
       --arg platform "${PLATFORM}" --arg task "${TASK}" \
       '.[$name] = {status: $status, last_heartbeat: $ts, platform: $platform, current_task: (if $task == "null" then null else $task end)}' \
       "${REGISTRY}" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "${REGISTRY}"
fi
