/**
 * Custom Slack MCP server — purposed tools replacing dual slack-bot/slack-user wrappers.
 * Plan: plans/in-progress/personal/2026-04-24-custom-slack-mcp.md
 *
 * 11 purposed tools encode routing intent. Agents call mcp__slack__notify_duong(text)
 * rather than choosing tokens + channel IDs at runtime.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
// Namespace import for Node 25 ESM/CJS interop.
// @slack/web-api is a pure-CJS package (no `exports` field, __esModule:true). Node 25's ESM
// loader cannot statically resolve named re-exports like `retryPolicies` from CJS packages.
// `import *` works for WebClient (direct namespace export) but retryPolicies is only accessible
// via the CJS module.exports default wrapper at runtime. The helper below abstracts the
// dual-access: in vitest (mocked), slackWebApi.retryPolicies is set by the mock factory;
// in Node 25 tsx (real runtime), it falls back to the CJS module.exports via default.
// See: plans/approved/personal/2026-04-24-slack-mcp-node25-cjs-fix
import * as slackWebApi from "@slack/web-api";
const { WebClient } = slackWebApi;

/**
 * Resolves retryPolicies from the @slack/web-api namespace.
 * In vitest, vi.mock factories expose retryPolicies as a direct named export on the namespace.
 * In Node 25 + tsx real runtime, the CJS module's retryPolicies is only accessible via
 * module.exports (the `.default` wrapper on the namespace object when __esModule:true is set).
 */
export function resolveRetryPolicies(): typeof slackWebApi.retryPolicies {
  if (slackWebApi.retryPolicies !== undefined) return slackWebApi.retryPolicies;
  // Node 25 CJS interop fallback: module.exports is exposed as .default on the namespace
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const cjsExports = (slackWebApi as any).default;
  if (cjsExports?.retryPolicies !== undefined) return cjsExports.retryPolicies;
  throw new Error(
    "slack-mcp: cannot resolve retryPolicies from @slack/web-api. " +
    "Check Node/tsx version compatibility."
  );
}
import { z } from "zod";
import { loadTokens, DUONG_USER_ID } from "./tokens.js";

// ---------------------------------------------------------------------------
// T13: Shared zod schemas
// ---------------------------------------------------------------------------

const channelId = z.string().min(1).describe("Slack channel ID (e.g. C12345)");
const threadTs = z.string().optional().describe("Thread timestamp for threading replies");
const text = z.string().min(1).describe("Message text (Slack mrkdwn supported)");
const userId = z.string().min(1).describe("Slack user ID (e.g. U12345)");
const fromAgent = z.string().optional().describe("Sending agent name — prefixes message as [agent] text");

// ---------------------------------------------------------------------------
// T14: from_agent prefix helper
// ---------------------------------------------------------------------------

/** Applies optional agent prefix: "[agentName] text" when from_agent is provided. */
function applyAgentPrefix(messageText: string, from_agent?: string): string {
  return from_agent ? `[${from_agent}] ${messageText}` : messageText;
}

// ---------------------------------------------------------------------------
// T13: Response envelope helpers
// ---------------------------------------------------------------------------

type TextContent = { type: "text"; text: string };
type McpContent = { content: TextContent[]; isError?: boolean };

function okEnvelope(payload: unknown): McpContent {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(payload) }],
  };
}

function errEnvelope(error: unknown): McpContent {
  const msg = error instanceof Error ? error.message : String(error);
  return {
    content: [{ type: "text" as const, text: msg }],
    isError: true,
  };
}

// ---------------------------------------------------------------------------
// T12: WebClient construction with retry config
// ---------------------------------------------------------------------------

/** Wraps a Slack API call; converts ok:false and SDK errors to MCP error envelopes. */
async function callSlack<T extends { ok: boolean; error?: string }>(
  fn: () => Promise<T>
): Promise<McpContent> {
  try {
    const result = await fn();
    if (!result.ok) {
      return errEnvelope(result.error ?? "slack_api_error");
    }
    return okEnvelope(result);
  } catch (err: unknown) {
    return errEnvelope(err);
  }
}

// ---------------------------------------------------------------------------
// createServer: wire all 11 tools
// ---------------------------------------------------------------------------

/**
 * Creates and configures the MCP server.
 * Reads tokens from environment (set by start.sh or test harness).
 * WebClient is constructed here — in tests, vi.mock('@slack/web-api') intercepts it.
 */
export function createServer(): McpServer {
  const tokens = loadTokens();

  // T12: both clients with fiveRetriesInFiveMinutes
  const retryPolicies = resolveRetryPolicies();
  const botClient = new WebClient(tokens.botToken, {
    retryConfig: retryPolicies.fiveRetriesInFiveMinutes,
  });
  const userClient = new WebClient(tokens.userToken, {
    retryConfig: retryPolicies.fiveRetriesInFiveMinutes,
  });

  const server = new McpServer({
    name: "slack",
    version: "1.0.0",
  });

  // ---------------------------------------------------------------------------
  // T15: notify_duong — bot DM to Duong's hardcoded user ID
  // ---------------------------------------------------------------------------

  server.tool(
    "notify_duong",
    "Send a DM notification to Duong. Channel is hardcoded; no routing decision needed.",
    {
      text,
      thread_ts: threadTs,
      from_agent: fromAgent,
    },
    async ({ text: msg, thread_ts, from_agent }) => {
      return callSlack(() =>
        botClient.chat.postMessage({
          channel: DUONG_USER_ID,
          text: applyAgentPrefix(msg, from_agent),
          ...(thread_ts ? { thread_ts } : {}),
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T16: post_as_bot — bot posts to any channel
  // ---------------------------------------------------------------------------

  server.tool(
    "post_as_bot",
    "Post a message as the bot to any channel. Bot must be invited to private channels.",
    {
      channel_id: channelId,
      text,
      thread_ts: threadTs,
      from_agent: fromAgent,
    },
    async ({ channel_id, text: msg, thread_ts, from_agent }) => {
      return callSlack(() =>
        botClient.chat.postMessage({
          channel: channel_id,
          text: applyAgentPrefix(msg, from_agent),
          ...(thread_ts ? { thread_ts } : {}),
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T16: post_as_duong — user token posts ghost-written as Duong
  // ---------------------------------------------------------------------------

  server.tool(
    "post_as_duong",
    "Ghost-write a message as Duong using the user token. Does not notify Duong.",
    {
      channel_id: channelId,
      text,
      thread_ts: threadTs,
      from_agent: fromAgent,
    },
    async ({ channel_id, text: msg, thread_ts, from_agent }) => {
      return callSlack(() =>
        userClient.chat.postMessage({
          channel: channel_id,
          text: applyAgentPrefix(msg, from_agent),
          ...(thread_ts ? { thread_ts } : {}),
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T17: reply_in_thread — thin dispatch over post_as_bot/post_as_duong
  // ---------------------------------------------------------------------------

  server.tool(
    "reply_in_thread",
    "Reply in a Slack thread as bot or as Duong. as='bot' (default) or as='duong'.",
    {
      channel_id: channelId,
      thread_ts: z.string().min(1).describe("Thread timestamp (required)"),
      text,
      as: z.enum(["bot", "duong"]).default("bot").describe("Identity to post as"),
      from_agent: fromAgent,
    },
    async ({ channel_id, thread_ts, text: msg, as: identity, from_agent }) => {
      const client = identity === "duong" ? userClient : botClient;
      return callSlack(() =>
        client.chat.postMessage({
          channel: channel_id,
          thread_ts,
          text: applyAgentPrefix(msg, from_agent),
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T18: add_reaction — bot adds emoji reaction
  // ---------------------------------------------------------------------------

  server.tool(
    "add_reaction",
    "Add an emoji reaction to a message as the bot.",
    {
      channel_id: channelId,
      timestamp: z.string().min(1).describe("Message timestamp"),
      emoji: z.string().min(1).describe("Emoji name without colons (e.g. thumbsup)"),
    },
    async ({ channel_id, timestamp, emoji }) => {
      return callSlack(() =>
        botClient.reactions.add({
          channel: channel_id,
          timestamp,
          name: emoji,
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T19: read_channel_history — user token reads channel messages
  // ---------------------------------------------------------------------------

  server.tool(
    "read_channel_history",
    "Read recent messages from a Slack channel using the user token.",
    {
      channel_id: channelId,
      limit: z.number().int().min(1).max(200).default(20).describe("Number of messages to return"),
      oldest: z.string().optional().describe("Start of time range (Unix timestamp)"),
      cursor: z.string().optional().describe("Pagination cursor"),
    },
    async ({ channel_id, limit, oldest, cursor }) => {
      return callSlack(() =>
        userClient.conversations.history({
          channel: channel_id,
          limit,
          ...(oldest ? { oldest } : {}),
          ...(cursor ? { cursor } : {}),
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T19: read_thread — user token reads thread replies
  // ---------------------------------------------------------------------------

  server.tool(
    "read_thread",
    "Read replies in a Slack thread using the user token.",
    {
      channel_id: channelId,
      thread_ts: z.string().min(1).describe("Thread timestamp"),
      limit: z.number().int().min(1).max(200).default(50).describe("Number of replies to return"),
    },
    async ({ channel_id, thread_ts, limit }) => {
      return callSlack(() =>
        userClient.conversations.replies({
          channel: channel_id,
          ts: thread_ts,
          limit,
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T19: read_dm — user token opens IM and reads DM history
  // ---------------------------------------------------------------------------

  server.tool(
    "read_dm",
    "Read DM conversation with a user. Opens the IM channel if needed.",
    {
      with_user_id: userId.describe("User ID to DM with"),
      limit: z.number().int().min(1).max(200).default(20).describe("Number of messages to return"),
    },
    async ({ with_user_id, limit }) => {
      // Step 1: open IM channel
      const openResult = await userClient.conversations.open({ users: with_user_id });
      if (!openResult.ok || !openResult.channel?.id) {
        return errEnvelope(openResult.error ?? "conversations_open_failed");
      }
      const dmChannelId = openResult.channel.id;

      // Step 2: read history
      return callSlack(() =>
        userClient.conversations.history({
          channel: dmChannelId,
          limit,
        })
      );
    }
  );

  // ---------------------------------------------------------------------------
  // T20: list_users — user token with client-side query filter
  // ---------------------------------------------------------------------------

  server.tool(
    "list_users",
    "List Slack workspace members. Optionally filter by query matching name, real_name, or display_name.",
    {
      query: z.string().optional().describe("Filter string matched against name, real_name, display_name"),
      limit: z.number().int().min(1).max(200).default(50).describe("Max members to return from API"),
    },
    async ({ query, limit }) => {
      const result = await userClient.users.list({ limit });
      if (!result.ok) {
        return errEnvelope(result.error ?? "users_list_failed");
      }

      let members = result.members ?? [];
      if (query) {
        const q = query.toLowerCase();
        members = members.filter((m) => {
          const name = (m.name ?? "").toLowerCase();
          const realName = (m.real_name ?? "").toLowerCase();
          const displayName = ((m.profile as { display_name?: string } | undefined)?.display_name ?? "").toLowerCase();
          return name.includes(q) || realName.includes(q) || displayName.includes(q);
        });
      }

      return okEnvelope(members);
    }
  );

  // ---------------------------------------------------------------------------
  // T20: list_channels — user token with is_member and archived filters
  // ---------------------------------------------------------------------------

  server.tool(
    "list_channels",
    "List Slack channels. Defaults to member-only, non-archived channels.",
    {
      query: z.string().optional().describe("Filter string matched against channel name"),
      member_only: z.boolean().default(true).describe("Only return channels the user is a member of"),
      include_archived: z.boolean().default(false).describe("Include archived channels"),
    },
    async ({ query, member_only, include_archived }) => {
      const result = await userClient.conversations.list({
        types: "public_channel,private_channel",
        exclude_archived: !include_archived,
      });
      if (!result.ok) {
        return errEnvelope(result.error ?? "conversations_list_failed");
      }

      let channels = result.channels ?? [];

      if (member_only) {
        channels = channels.filter((c) => c.is_member);
      }

      if (!include_archived) {
        channels = channels.filter((c) => !c.is_archived);
      }

      if (query) {
        const q = query.toLowerCase();
        channels = channels.filter((c) => (c.name ?? "").toLowerCase().includes(q));
      }

      return okEnvelope(channels);
    }
  );

  // ---------------------------------------------------------------------------
  // T21: resolve_user — strip @, search users.list, return {user_id, real_name, tz}
  // ---------------------------------------------------------------------------

  server.tool(
    "resolve_user",
    "Resolve a Slack user by handle or display name. Returns user_id, real_name, tz.",
    {
      handle: z.string().min(1).describe("Username or @handle to resolve"),
    },
    async ({ handle }) => {
      const stripped = handle.startsWith("@") ? handle.slice(1) : handle;
      const q = stripped.toLowerCase();

      const result = await userClient.users.list({ limit: 200 });
      if (!result.ok) {
        return errEnvelope(result.error ?? "users_list_failed");
      }

      const members = result.members ?? [];
      const found = members.find((m) => {
        const name = (m.name ?? "").toLowerCase();
        const realName = (m.real_name ?? "").toLowerCase();
        const displayName = ((m.profile as { display_name?: string } | undefined)?.display_name ?? "").toLowerCase();
        return name === q || realName === q || displayName === q ||
          name.includes(q) || realName.includes(q) || displayName.includes(q);
      });

      if (!found) {
        return errEnvelope("user_not_found");
      }

      return okEnvelope({
        user_id: found.id,
        real_name: found.real_name,
        tz: found.tz,
      });
    }
  );

  return server;
}

async function main(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

// Only run main() when this file is the entry point (not when imported by tests)
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((err: unknown) => {
    console.error("slack-mcp: fatal error:", err);
    process.exit(1);
  });
}
