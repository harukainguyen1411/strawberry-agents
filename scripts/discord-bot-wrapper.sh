#!/usr/bin/env bash
set -euo pipefail

# Load Discord secrets
set -a
source /home/runner/.env.discord
set +a

exec node /home/runner/strawberry/apps/discord-relay/src/index.js
