/**
 * Token loader for the custom Slack MCP server.
 * Reads SLACK_BOT_TOKEN + SLACK_USER_TOKEN from the process environment.
 * Throws a typed error naming the missing variable if either is absent.
 */

export class MissingTokenError extends Error {
  constructor(public readonly varName: string) {
    super(`slack-mcp: missing required environment variable: ${varName}`);
    this.name = "MissingTokenError";
  }
}

export interface SlackTokens {
  botToken: string;
  userToken: string;
}

/**
 * Load both Slack tokens from the environment.
 * Throws MissingTokenError naming the first missing variable.
 */
export function loadTokens(): SlackTokens {
  const botToken = process.env.SLACK_BOT_TOKEN;
  if (!botToken) {
    throw new MissingTokenError("SLACK_BOT_TOKEN");
  }

  const userToken = process.env.SLACK_USER_TOKEN;
  if (!userToken) {
    throw new MissingTokenError("SLACK_USER_TOKEN");
  }

  return { botToken, userToken };
}

/** Duong's Slack user ID — env-overridable, defaults to known value. */
export const DUONG_USER_ID = process.env.DUONG_USER_ID ?? "U03KDE6SS9J";

/** Workspace team ID — env-overridable, defaults to known value. */
export const SLACK_TEAM_ID = process.env.SLACK_TEAM_ID ?? "T18MLBHC5";
