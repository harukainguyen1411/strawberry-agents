# Strawberry coordinator launchers.
# Source from ~/.zshrc:
#   source ~/Documents/Personal/strawberry-agents/scripts/mac/aliases.sh
#
# --channels server:strawberry-inbox  — activates the inbox channel for the session
# --dangerously-load-development-channels — required during Channels research preview
#   for local plugins not yet on Anthropic's approved allowlist
# STRAWBERRY_AGENT — fallback identity for the channel plugin if CLAUDE_AGENT_NAME
#   is not exported by the claude CLI into the plugin subprocess environment

alias evelynn='cd ~/Documents/Personal/strawberry-agents && STRAWBERRY_AGENT=evelynn claude --agent evelynn --plugin-dir .claude/plugins/strawberry-inbox --channels server:strawberry-inbox --dangerously-load-development-channels'
alias sona='cd ~/Documents/Personal/strawberry-agents && STRAWBERRY_AGENT=sona claude --agent sona --plugin-dir .claude/plugins/strawberry-inbox --channels server:strawberry-inbox --dangerously-load-development-channels'
