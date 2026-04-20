---
date: 2026-04-09
topic: Slack → Claude Code agent trigger architecture
---

# Slack → Claude Code Agent Trigger: What's Actually Possible

## Key Findings

### 1. Native Slack Integration (Official)
- Anthropic has a native "Claude Code in Slack" feature (announced Dec 2025)
- Installed via Slack App Marketplace (App ID: A08SF47R6P4)
- User @mentions @Claude → Anthropic's backend routes to a Claude Code on the Web session
- Requires: Pro/Max/Team/Enterprise plan + Claude Code on the Web access + GitHub account connected
- Sessions run on Anthropic's infrastructure (claude.ai/code), not local machines
- GitHub only (no GitLab, Bitbucket support yet)
- Does NOT expose webhooks or a programmatic trigger — it's a managed Anthropic service

### 2. Headless/Programmatic Mode (Agent SDK)
- `claude -p "prompt" --allowedTools "Read,Edit,Bash"` runs Claude Code non-interactively
- Now officially called the **Claude Agent SDK** (previously "headless mode")
- Available as Python (`claude-agent-sdk`) and TypeScript (`@anthropic-ai/claude-agent-sdk`) packages
- Requires ANTHROPIC_API_KEY — cannot use claude.ai subscription login for programmatic calls
- API key pricing applies (pay per token), NOT subscription rate limits
- `--bare` flag recommended for CI/scripts: skips CLAUDE.md, MCPs, hooks from local config

### 3. RemoteTrigger Tool
- No tool named "RemoteTrigger" exists in official Claude Code docs
- What does exist: **Remote Control** feature (v2.1.52+) — creates encrypted bridge from terminal to Claude mobile app
- Allows monitoring/approving from phone, but doesn't remotely trigger new sessions
- The question about "RemoteTrigger" may conflate this with the Agent SDK's programmatic invocation

### 4. API Key vs Subscription
- Claude Code CLI (interactive): uses claude.ai subscription (Pro/Max)
- Agent SDK / headless `-p` mode: requires ANTHROPIC_API_KEY from platform.claude.com
- You CANNOT use a subscription account to run programmatic/automated agents via API
- Anthropic explicitly states third-party products must use API key auth, not claude.ai login

### 5. Community Patterns
- `claude-code-slack-bot` by mpociot on GitHub: connects local Claude Code to Slack
- `Claude-Code-Remote` by JessyTsui: trigger via email/Discord/Telegram → local session
- General pattern: Slack bot webhook → shell script → `claude -p "task"` → post result to Slack

## Recommended Architecture (Custom, Self-Hosted)

```
Slack mention → Slack Events API (webhook) 
  → Node/Python server (receives event, extracts task text)
    → spawn: claude -p "task" --bare --allowedTools "Read,Edit,Bash,Glob,Grep" --output-format json
      → capture stdout (JSON result)
        → post reply to Slack thread via Slack Web API
```

Or use the Agent SDK for more control:
- Slack Events API → server → `claude_agent_sdk.query(prompt=task)` → stream result → post to Slack

## Tradeoffs
| Approach | Pros | Cons |
|---|---|---|
| Native Anthropic Slack app | Zero setup, managed | GitHub only, Anthropic infra, no control |
| Agent SDK + custom Slack bot | Full control, any repo/tool | Requires API key (paid per token), server to host |
| `claude -p` shell + Slack webhook | Simple, scriptable | Less control over streaming, no SDK features |

