# Slack bot vs user token — notification routing

**Date:** 2026-04-24
**Session:** 5e94cd09 (pre-compact 2)
**Trigger:** Slack MCP dual-token wiring (Ekko initial wiring → Lux custom-MCP spec)

## What was learned

Slack routes notifications by the *underlying author identity*, not by channel or permission scope. A user token (`xoxp-`) always posts as Duong's human account. Slack does not generate notification pings for messages you yourself authored, regardless of channel membership or notification settings. As a result:

- **`xoxp-` tokens cannot notify Duong** via any channel — even direct messages — because Slack treats the message as self-authored.
- **Bot tokens (`xoxb-`) can notify** because the message author is the bot app, which is a distinct identity. DM to Duong's user ID `U03KDE6SS9J` via bot token generates a real ping.
- Canonical channel `C0ANVLZQ17X` was noted for agent notifications but is **deprecated as a notification target** — the bot DM approach is canonical.

## Generalizable rule

Any Slack notification flow that must actually ping a human should use a bot token and DM to that user's Slack user ID. Never rely on xoxp- tokens for notification purposes, even in channels the user is a member of.

## Impact

Affects Slack MCP design (`plans/in-progress/personal/2026-04-24-custom-slack-mcp.md`) and any future notification-routing decisions. Kayn's 27-task breakdown and Jayce's implementation both incorporate this understanding.
