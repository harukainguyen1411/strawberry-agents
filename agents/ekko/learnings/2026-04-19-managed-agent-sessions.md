# Managed Agent Sessions — Anthropic API

Date: 2026-04-19

## Context

demo-studio Managed Agent (agent_011Ca9Dk3H4m6DYcA6e489Ew) accumulates idle sessions over time.
Sessions are listed and archived via `anthropic` Python SDK — `client.beta.sessions`, not `client.beta.agents.sessions`.

## Key facts

- Agent/env/vault IDs live in `company-os/tools/demo-studio-v3/.agent-ids.env`
- ANTHROPIC_API_KEY lives in `company-os/tools/demo-studio-v3/.env`
- Sessions list: `client.beta.sessions.list()` (global, not per-agent)
- Archive a session: `client.beta.sessions.archive(session_id)`
- 45 idle sessions were found and archived on 2026-04-19
