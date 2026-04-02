#!/bin/bash
agent=$1
mode=${2:-direct}
if [ -z "$agent" ]; then
    echo "Usage: launch-agent.sh <agent-name> [autonomous|direct]"
    exit 1
fi

WORKDIR=/Users/duongntd99/Personal/strawberry

osascript <<EOF
tell application "iTerm"
    create window with profile "${agent}"
    tell current session of current window
        write text "cd ${WORKDIR} && claude"
    end tell
    activate
end tell
EOF

sleep 3

if [ "$mode" = "autonomous" ]; then
    GREETING="[autonomous] ${agent}, you have been launched by another agent. Check your inbox for tasks."
else
    GREETING="Hey ${agent}"
fi

osascript <<EOF
tell application "iTerm" to activate
delay 0.3
tell application "System Events" to tell process "iTerm2"
    keystroke "${GREETING}"
    delay 0.3
    keystroke return
end tell
EOF
