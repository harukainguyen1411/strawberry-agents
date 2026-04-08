# discord-mcp

Thin wrapper around [`barryyip0625/mcp-discord`](https://github.com/barryyip0625/mcp-discord)
that injects the Evelynn bot token from `secrets/` and exec's the upstream
server over stdio. No in-house server code — all tools are provided by the
upstream package.

## Why this one

- Actively maintained (121+ commits as of March 2026, tool count doubled
  that month).
- Native stdio transport (streamable HTTP is available but unused here).
- First-class forum channel support — Strawberry's Discord triage flow uses
  a forum channel, so this was the differentiator vs. other Discord MCPs.

## Auth

At startup, `scripts/start.sh` reads `secrets/discord-bot-token.txt` (the
same file `apps/discord-relay/` uses — one bot identity, two clients: the
long-running triage bot holds the Gateway socket, this MCP uses REST only)
and passes it to the upstream via its `--config` flag. The token never
lands in `.mcp.json` or any process env printed in logs.

To rotate: overwrite `secrets/discord-bot-token.txt` with the new token
from the Discord developer portal. No code change needed.

## Tools exposed

All tool names come straight from upstream — see the
[upstream README](https://github.com/barryyip0625/mcp-discord) for full
argument schemas.

**Basic**
- `discord_login`
- `discord_list_servers`
- `discord_send`
- `discord_get_server_info`

**Channel management**
- `discord_create_text_channel`, `discord_create_forum_channel`, `discord_create_voice_channel`
- `discord_edit_channel`, `discord_delete_channel`
- `discord_create_category`, `discord_edit_category`, `discord_delete_category`
- `discord_set_channel_permissions`, `discord_remove_channel_permissions`

**Forum**
- `discord_get_forum_channels`
- `discord_create_forum_post`
- `discord_get_forum_post`
- `discord_list_forum_threads`
- `discord_reply_to_forum`
- `discord_get_forum_tags`, `discord_set_forum_tags`
- `discord_update_forum_post`, `discord_delete_forum_post`

**Messages and reactions**
- `discord_search_messages`, `discord_read_messages`
- `discord_edit_message`, `discord_delete_message`
- `discord_add_reaction`, `discord_add_multiple_reactions`, `discord_remove_reaction`

**Webhooks**
- `discord_create_webhook`, `discord_send_webhook_message`, `discord_edit_webhook`, `discord_delete_webhook`

**Roles**
- `discord_list_roles`, `discord_create_role`, `discord_edit_role`, `discord_delete_role`, `discord_assign_role`, `discord_remove_role`

**Members**
- `discord_list_members`, `discord_get_member`

## Registration

See the `discord` entry in the repo-root `.mcp.json`. It points at
`scripts/start.sh`, which is responsible for token load + `npx -y mcp-discord`.

## Discord permissions

Evelynn's bot already has MESSAGE CONTENT intent enabled and is in the
Strawberry guild. Permission bits the bot needs on the channels/forums it
acts on:

- `ViewChannel`, `ReadMessageHistory`
- `SendMessages`, `SendMessagesInThreads`
- `CreatePublicThreads` (forum posts)
- `AddReactions`
- `ManageChannels`, `ManageRoles`, `ManageWebhooks` (only if the channel
  management / roles / webhook tool families are used; safe to omit until
  a concrete flow needs them)

## Do not touch

- `apps/discord-relay/` — live triage bot, different process, Gateway
  connection, separate codebase. Never reach into it from here.
- `secrets/discord-bot-token.txt` — read-only from this MCP's perspective.

## See also

- Plan: `plans/approved/2026-04-09-discord-mcp-server.md`
- Upstream: https://github.com/barryyip0625/mcp-discord
