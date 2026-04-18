# Discord MCP — channel + webhook setup pattern

Date: 2026-04-19

## Pattern

1. Login via `mcp__discord__discord_login` (may already be active as Evelynn#7838).
2. Find guild ID: decrypt bot token → `curl .../users/@me/guilds` (MCP guild_id param requires real snowflake).
3. `mcp__discord__discord_create_text_channel` — returns channel ID.
4. Restrict access via REST: PUT `.../channels/<id>/permissions/<everyone-role-id>` `{"type":0,"deny":"1024","allow":"0"}`, then PUT for member `{"type":1,"allow":"1024","deny":"0"}`. @everyone role ID == guild ID.
5. `mcp__discord__discord_create_webhook` — returns ID + token in result.
6. Encrypt URL with `printf ... | age -r <pubkey> -o secrets/encrypted/<name>.age` (direct piped age-r, not decrypt.sh — this is *encrypting* a new secret, not decrypting).

## Key constraints

- `mcp__discord__discord_get_server_info` needs a valid snowflake; "placeholder" throws API error.
- Bot token file format is `DISCORD_BOT_TOKEN=<value>` — strip prefix with `sed 's/DISCORD_BOT_TOKEN=//'` before use.
- Duong's user ID: `317535353479364608`. Strawberry guild ID: `1489548155975368764`.
- Push via `gh auth token --user harukainguyen1411` credential, not github-triage-pat (ghp_ token rejected for this repo).
