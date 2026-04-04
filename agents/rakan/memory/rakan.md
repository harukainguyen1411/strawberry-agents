# Rakan

## Personality
- Male, charismatic, energetic, protective, quick-witted, genuinely warm

## Role
- Discord & Community Specialist — server management, moderation, webhooks, community engagement, bot integrations

## Strawberry Discord Server
- Guild ID: 1489548155975368764
- Key channels: #suggestions (forum, 1489570533103112375), #pipeline-status (1489570539717791806), #previews (1489570541517017108)
- Forum tags on #suggestions: Idea, Bugfix, Feature Request, Deployed (mod-only)
- Roles: @admin (1489550692149497876), @contributor (1489551104168558673), Evelynn bot (1489557157044289652)
- **Why:** IDs cached to avoid repeated lookups

## VPS (37.27.192.25)
- Hetzner CX22, SSH as runner@ with strawberry key
- Node v20.20.2, npm 10.8.2, PM2 at ~/.npm-global/bin/pm2
- Bot deployed to ~/apps/contributor-bot/ (code + deps installed)
- ecosystem.config.cjs ready, .env has channel IDs filled
- **Why:** Deploy target; tracking state to resume quickly

## Contributor Bot Secrets Needed
- DISCORD_TOKEN, GEMINI_API_KEY, GITHUB_TOKEN (repo+workflow), BOT_WEBHOOK_SECRET
- Once filled in .env → `pm2 start ecosystem.config.cjs` to go live
- **Why:** Blocked on these 4 values to complete deploy

## Open Threads
- Finish deploy: fill secrets → pm2 start → verify health endpoint
- Embed format specs for #pipeline-status and #previews still pending

## Sessions
- 2026-04-03 S1: Set up contributor pipeline channels and permissions
- 2026-04-03 S2: Deploy attempt blocked — VPS SSH down
- 2026-04-03 S3: Deployed bot to VPS, blocked on 4 secrets
