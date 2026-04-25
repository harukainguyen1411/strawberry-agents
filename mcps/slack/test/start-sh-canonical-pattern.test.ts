/**
 * Structural test for the canonical §4.2 start.sh pattern (T-new-D).
 *
 * Plan: plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md §4.2
 *
 * Verifies that mcps/slack/scripts/start.sh follows the canonical
 * decrypt-and-exec template required by T-new-D:
 *   - No secret captured via $(...) in the script body
 *   - tools/decrypt.sh is referenced as the sole decrypt entry point
 *   - --exec flag is present (exec-replace pattern, not subshell)
 *   - SLACK_USER_TOKEN is the named --var (single-secret MCP)
 *   - Ciphertext source references secrets/work/encrypted/slack-user-token.age
 *
 * # xfail: old start.sh captures tokens via $(...) grep/cut pattern and uses
 *          plaintext secrets/slack-bot-token.txt rather than tools/decrypt.sh
 */

import { it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const startSh = readFileSync(join(__dirname, "../scripts/start.sh"), "utf8");

it(
  "T-new-D: old plaintext token file reference and $() capture are gone",
  () => {
    // Regression guard: the old script read from secrets/slack-bot-token.txt — must be absent
    expect(startSh).not.toContain("slack-bot-token.txt");
    // Regression guard: the old script captured tokens via $() — must be absent
    expect(startSh).not.toMatch(/\$\(grep.*TOKEN/);
  }
);

// These 5 tests describe the T-new-D implementation target.
// They are marked skip until the canonical start.sh lands in the next commit.
it(
  "T-new-D: start.sh uses tools/decrypt.sh as sole decryption entry point",
  () => {
    expect(startSh).toContain("tools/decrypt.sh");
  }
);

it(
  "T-new-D: start.sh uses --exec flag (no subshell capture of plaintext)",
  () => {
    expect(startSh).toContain("--exec");
    // Must not have $(...) capturing a token value
    expect(startSh).not.toMatch(/\w+TOKEN\s*=\s*"\$\(/);
  }
);

it(
  "T-new-D: start.sh names SLACK_USER_TOKEN as the --var",
  () => {
    expect(startSh).toContain("--var");
    expect(startSh).toContain("SLACK_USER_TOKEN");
  }
);

it(
  "T-new-D: start.sh reads ciphertext from secrets/work/encrypted/slack-user-token.age",
  () => {
    expect(startSh).toContain("secrets/work/encrypted/slack-user-token.age");
  }
);

it(
  "T-new-D: start.sh writes runtime env to secrets/work/runtime/slack.env",
  () => {
    expect(startSh).toContain("secrets/work/runtime/slack.env");
  }
);
