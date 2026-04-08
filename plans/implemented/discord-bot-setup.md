---
status: active
owner: bard
gdoc_id: 1O0NducUNeXVBrfhIEOQ96EErYq19hYFHGYTiRhSVaOA
gdoc_url: https://docs.google.com/document/d/1O0NducUNeXVBrfhIEOQ96EErYq19hYFHGYTiRhSVaOA/edit
---

# Discord Bot Setup — For MCP Integration

Duong needs to complete these steps to activate the Discord MCP server.

## 1. Create a Discord Application & Bot

1. Go to https://discord.com/developers/applications
2. Click **New Application** → name it (e.g. "myapps-bot") → Create
3. Go to **Bot** tab (left sidebar)
4. Click **Reset Token** → copy the token immediately (shown once)
5. Save this token — you'll need it in step 3

## 2. Enable Required Intents

Still on the Bot tab, scroll to **Privileged Gateway Intents** and enable:
- **Server Members Intent** — needed for role/member management
- **Message Content Intent** — needed for reading messages

Click **Save Changes**.

## 3. Invite the Bot to Your Server

1. Go to **OAuth2** tab → **URL Generator**
2. Scopes: check **bot** and **applications.commands**
3. Bot Permissions: check **Administrator** (simplest) or selectively:
   - Manage Channels, Manage Roles, Manage Webhooks
   - Send Messages, Read Message History, Embed Links
   - Manage Messages, Add Reactions
4. Copy the generated URL → open in browser → select your server → Authorize

## 4. Get Your Guild (Server) ID

1. In Discord, go to Settings → Advanced → enable **Developer Mode**
2. Right-click your server name → **Copy Server ID**

## 5. Add Credentials to MCP Config

Edit `.mcp.json` in the strawberry repo — the `discord` server is already configured. Just fill in:

```json
"DISCORD_BOT_TOKEN": "your-bot-token-here",
"DISCORD_GUILD_ID": "your-server-id-here"
```

## 6. Verify

Restart Claude Code. The discord MCP tools should appear. Test with a simple operation like listing channels.

## MCP Server Details

- Package: `@pasympa/discord-mcp` (v1.4.1)
- 90+ tools: channels, roles, messages, webhooks, moderation, threads, forums
- Multi-guild support, lightweight (3 dependencies)
- Runs via `npx` — no local install needed
