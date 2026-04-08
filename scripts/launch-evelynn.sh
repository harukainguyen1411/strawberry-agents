#!/usr/bin/env bash
# Launch Evelynn on Mac — Remote Control + dangerously-skip-permissions
cd "$(dirname "$0")/.."
claude --dangerously-skip-permissions --remote-control "Hey Evelynn"
