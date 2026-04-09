---
title: Discord per-app channel triage
status: proposed
owner: bard
date: 2026-04-09
---

# Discord Per-App Channel Triage

## Summary

Restructure the Discord triage pipeline from a single `#suggestions` channel to a per-app channel layout under an "App Feedback" category. The discord-relay bot gains multi-channel listening with channel-ID-based routing, so each message is automatically tagged with the correct app name and issue type (bug, feature request, or new-app proposal). GitHub issues get per-app and per-type labels.

## Current State

- One `#suggestions` channel, all messages go through Gemini triage, all issues labeled `myapps`.
- Bot config: single `TRIAGE_DISCORD_CHANNEL_ID` env var.
- Code at `apps/discord-relay/`, Node/TypeScript, discord.js Gateway, Gemini 2.0 Flash triage, Octokit issue filing.

## Day-One App Set

Day-one channels cover all public-use apps in `apps/myapps/`. Personal-use apps (coder-worker, contributor-bot, discord-relay) are internal tools and do not get public feedback channels.

Currently `apps/myapps/` is the only public-use app, so the day-one set is:

- **myapps** — the MyApps web application (`apps/myapps/`)

As new public-use apps are added under `apps/myapps/` (or as sibling directories following the same pattern), they get onboarded with a channel pair and a `channel-map.json` entry.

## Target State

- Discord category "App Feedback" containing per-app channel pairs plus one special channel.
- Bot listens to all channels in the category, derives app name and issue type from channel ID.
- GitHub issues carry labels like `app:myapps`, `type:bug`, `type:feature`, `type:new-app`.

---

## 1. Discord Server Structure

### Category: "App Feedback"

Create a Discord category named **App Feedback**. All triage channels live under it.

**Per-app channel pairs** (one pair per registered app):

| Channel | Purpose | Maps to label |
|---------|---------|---------------|
| `#myapps-requests` | Feature requests for MyApps | `app:myapps` + `type:feature` |
| `#myapps-issues` | Bug reports for MyApps | `app:myapps` + `type:bug` |

Add more pairs as new public-use apps are onboarded.

**Special channel:**

| Channel | Purpose | Maps to label |
|---------|---------|---------------|
| `#new-app-requests` | Proposals for entirely new apps | `type:new-app` (no `app:` label) |

### Permissions

- All channels inherit category permissions (friends can post, bot can read+write).
- Bot needs `VIEW_CHANNEL` + `SEND_MESSAGES` on the category.

---

## 2. Discord-Relay Code Changes

### 2a. Channel routing config

Replace the single `TRIAGE_DISCORD_CHANNEL_ID` env var with a JSON config file at `apps/discord-relay/channel-map.json`:

```json
{
  "channels": {
    "CHANNEL_ID_1": { "app": "myapps", "type": "feature" },
    "CHANNEL_ID_2": { "app": "myapps", "type": "bug" },
    "CHANNEL_ID_3": { "app": null, "type": "new-app" }
  },
  "categoryId": "CATEGORY_ID"
}
```

**Why a file, not env vars:** The mapping will grow with each app. A JSON file is version-controlled and readable. Channel IDs are not secrets.

Add a new env var `CHANNEL_MAP_PATH` (defaults to `./channel-map.json`).

### 2b. Multi-channel listener

In `src/discord-bot.ts` (or equivalent message handler):

- On `messageCreate`, check if `message.channelId` exists in the channel map. If not, ignore.
- Look up `{ app, type }` from the map.
- Pass `app` and `type` to the triage function alongside the message content.

### 2c. Triage prompt changes

In `src/gemini.ts`, adjust the system prompt:

- Include the app name in context: "This message is about the app **{app}**" (or "This is a request for a new app" when `type === "new-app"`).
- For per-app channels, scope the context cache to that app's subtree (e.g., `apps/myapps/triage-context.md` for myapps). Fall back to repo-wide context for `new-app-requests`.
- Gemini still decides title, body, priority, and dupe detection. It no longer needs to guess which app the message is about -- the channel tells us.

### 2d. Issue filing changes

In `src/github.ts`:

- Build labels array from the channel map entry: `["app:{app}", "type:{type}"]`.
- For `new-app-requests`, labels are `["type:new-app"]` only.
- Prefix issue title with app name: `[myapps] Fix login redirect` or `[new-app] Expense tracker`.
- Keep the existing `myapps` label for backward compatibility during migration (see section 5).

---

## 3. GitHub Label Strategy

### Create these labels in the Strawberry repo:

**App labels** (green family):
- `app:myapps`
- (add per app as onboarded)

**Type labels** (blue family):
- `type:bug`
- `type:feature`
- `type:new-app`

**Priority labels** (unchanged -- Gemini already assigns these):
- `priority:high`, `priority:medium`, `priority:low`

The existing `myapps` label stays as-is for backward compat. New issues get both `myapps` and `app:myapps` during the transition; after migration the old label can be retired.

---

## 4. How `#new-app-requests` Differs

| Aspect | Per-app channels | `#new-app-requests` |
|--------|-----------------|---------------------|
| App name | Known from channel | Unknown -- Gemini extracts a proposed name |
| Context scope | App-specific subtree | Repo-wide (to check if app already exists) |
| GitHub labels | `app:{name}` + `type:bug/feature` | `type:new-app` only |
| Title prefix | `[appname]` | `[new-app]` |
| Gemini prompt | "Classify this bug/feature for {app}" | "Extract the proposed app idea, check for overlap with existing apps" |

When a new-app request is approved and the app is created, the implementer adds a channel pair and updates `channel-map.json`.

---

## 5. Migration Path

**Phase 1 -- Parallel operation (no downtime):**
1. Create the "App Feedback" category and all channels in Discord.
2. Deploy updated bot code with `channel-map.json` that includes both the old `#suggestions` channel (mapped to `app:myapps`, `type:feature` as default) and the new per-app channels.
3. Post an announcement in `#suggestions` directing friends to use the new channels.

**Phase 2 -- Cutover:**
1. After 1-2 weeks, remove `#suggestions` from the channel map (bot stops listening).
2. Archive `#suggestions` in Discord (read-only, not deleted).
3. Remove the legacy `TRIAGE_DISCORD_CHANNEL_ID` env var and related code paths.
4. Retire the bare `myapps` label once all old issues are closed or relabeled.

---

## 6. Config and Env Changes

| Change | File/Location | Notes |
|--------|--------------|-------|
| New file | `apps/discord-relay/channel-map.json` | Channel ID to app+type mapping |
| New env var | `CHANNEL_MAP_PATH` | Optional, defaults to `./channel-map.json` |
| Deprecated env var | `TRIAGE_DISCORD_CHANNEL_ID` | Keep during Phase 1, remove at Phase 2 |
| New env var (optional) | `TRIAGE_CATEGORY_ID` | Used if bot auto-discovers channels in category instead of explicit map |
| GitHub labels | Repo settings | Create `app:*` and `type:*` labels |
| triage-context.md | Per-app: `apps/{appname}/triage-context.md` | Each app gets its own context file for scoped triage |

### NSSM Service

No changes to the Windows NSSM service configuration beyond updating env vars. The service continues to run the same entry point.

---

## Open Questions

1. **Per-app context caching:** Currently one monolithic context cache. Splitting to per-app means multiple Gemini context caches in memory. At current scale (1 app) this is a non-issue. Worth noting for future scaling.
