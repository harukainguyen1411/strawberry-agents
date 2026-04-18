#!/usr/bin/env bash
# setup-discord-channels.sh
#
# Idempotent script to create the "App Feedback" Discord category and per-app
# channel pairs via the Discord REST API using the bot token.
#
# Prerequisites:
#   - node (for the inline discord.js REST call)
#   - secrets/discord-bot-token.txt must contain a valid bot token
#   - The bot must be a member of the target guild with Manage Channels permission
#
# Usage:
#   bash scripts/setup-discord-channels.sh <guild_id>
#
# After running, copy the output JSON snippet into apps/discord-relay/channel-map.json.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TOKEN_FILE="${REPO_ROOT}/secrets/discord-bot-token.txt"

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/setup-discord-channels.sh <guild_id>"
  echo ""
  echo "Find your guild ID by enabling Developer Mode in Discord and right-clicking your server."
  exit 1
fi

GUILD_ID="$1"

if [ ! -f "${TOKEN_FILE}" ]; then
  echo "ERROR: Bot token not found at ${TOKEN_FILE}"
  echo "Create the file with your Discord bot token (no trailing newline)."
  exit 1
fi

# Delegate to a small Node script so we get proper async/await and discord.js REST
REPO_ROOT="${REPO_ROOT}" GUILD_ID="${GUILD_ID}" node --input-type=module <<'JS'
import { REST, Routes, ChannelType } from 'discord.js';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const repoRoot = process.env.REPO_ROOT;
const guildId = process.env.GUILD_ID;
const token = readFileSync(resolve(repoRoot, 'secrets/discord-bot-token.txt'), 'utf8').trim();

const rest = new REST({ version: '10' }).setToken(token);

// --- Fetch existing channels ---
const existing = await rest.get(Routes.guildChannels(guildId));

function findByName(name, type) {
  return existing.find(
    (c) => c.name.toLowerCase() === name.toLowerCase() && c.type === type
  );
}

// --- Category ---
const CATEGORY_NAME = 'App Feedback';
let category = findByName(CATEGORY_NAME, ChannelType.GuildCategory);
if (category) {
  console.log(`Found existing category "${CATEGORY_NAME}": ${category.id}`);
} else {
  category = await rest.post(Routes.guildChannels(guildId), {
    body: { name: CATEGORY_NAME, type: ChannelType.GuildCategory },
  });
  console.log(`Created category "${CATEGORY_NAME}": ${category.id}`);
}

// --- Channel definitions ---
const channels = [
  { name: 'myapps-requests', app: 'myapps', type: 'feature' },
  { name: 'myapps-issues',   app: 'myapps', type: 'bug' },
  { name: 'new-app-requests', app: null,    type: 'new-app' },
];

const channelMap = {};
for (const def of channels) {
  let ch = findByName(def.name, ChannelType.GuildText);
  if (ch) {
    console.log(`Found existing channel #${def.name}: ${ch.id}`);
  } else {
    ch = await rest.post(Routes.guildChannels(guildId), {
      body: {
        name: def.name,
        type: ChannelType.GuildText,
        parent_id: category.id,
      },
    });
    console.log(`Created channel #${def.name}: ${ch.id}`);
  }
  channelMap[ch.id] = { app: def.app, type: def.type };
}

// --- Output snippet ---
console.log('');
console.log('channel-map.json snippet:');
console.log(JSON.stringify({
  channels: channelMap,
  categoryId: category.id,
}, null, 2));
JS
