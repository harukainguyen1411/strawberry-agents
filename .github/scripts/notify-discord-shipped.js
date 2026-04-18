#!/usr/bin/env node
// Notify Discord relay that a merge deploy has completed (kind: "shipped").
// Parses strawberry-meta from the squash-merge commit message.
// Vanilla Node — no external dependencies.

const https = require("https");
const http = require("http");
const crypto = require("crypto");
const { URL } = require("url");

const META_RE = /<!-- strawberry-meta\n([\s\S]*?)\n-->/;

function parseStrawberryMeta(text) {
  if (!text) return null;
  const match = text.match(META_RE);
  if (!match) return null;
  const result = {};
  for (const line of match[1].split("\n")) {
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const val = line.slice(idx + 1).trim();
    if (key && val) result[key] = val;
  }
  return Object.keys(result).length > 0 ? result : null;
}

function sign(secret, body) {
  return "sha256=" + crypto.createHmac("sha256", secret).update(body).digest("hex");
}

function post(url, body, signature) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const lib = parsed.protocol === "https:" ? https : http;
    const req = lib.request(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === "https:" ? 443 : 80),
        path: parsed.pathname + parsed.search,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Strawberry-Signature": signature,
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(data);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  const webhookUrl = process.env.DISCORD_RELAY_WEBHOOK_URL;
  const webhookSecret = process.env.DISCORD_RELAY_WEBHOOK_SECRET;

  if (!webhookUrl || !webhookSecret) {
    console.log("DISCORD_RELAY_WEBHOOK_URL or SECRET not set — skipping notification.");
    process.exit(0);
  }

  // Parse strawberry-meta from squash-merge commit message
  const commitMessage = process.env.COMMIT_MESSAGE || "";
  const meta = parseStrawberryMeta(commitMessage);
  if (!meta) {
    console.log("No strawberry-meta block in commit message — skipping shipped notification.");
    process.exit(0);
  }

  const payload = JSON.stringify({
    kind: "shipped",
    repo: process.env.REPO,
    prod_url: process.env.PROD_URL || `https://${process.env.FIREBASE_PROJECT_ID || "myapps-b31ea"}.web.app`,
    discord_channel_id: meta.discord_channel_id,
    discord_user_id: meta.discord_user_id,
    discord_message_id: meta.discord_message_id,
  });

  const signature = sign(webhookSecret, payload);

  try {
    await post(webhookUrl, payload, signature);
    console.log("Discord relay notified: shipped.");
  } catch (err) {
    console.error("Failed to notify Discord relay:", err.message);
    process.exit(0);
  }
}

main();
