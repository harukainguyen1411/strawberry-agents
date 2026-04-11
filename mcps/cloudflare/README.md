# Cloudflare MCP Server

Wraps `@cloudflare/mcp-server-cloudflare` — official Cloudflare MCP server covering DNS, Workers, KV, R2, D1, and other Cloudflare APIs.

## Prerequisites

- `secrets/cloudflare.env` must exist with `CF_API_TOKEN=<your-api-token>`
- `npx` available on PATH

## Usage

Started automatically by Claude Code via `.mcp.json`. The wrapper script sources `secrets/cloudflare.env` and exports `CLOUDFLARE_API_TOKEN` before launching the server.
