# 2026-04-10 — Agent team coordination lessons

## Reviewers need real models
Putting code reviewers (Jhin, Senna) on haiku was a mistake — they miss nuance and produce false positives. Jhin on haiku flagged a correct code change as a bug (toClaimTool navigation). After promotion to sonnet, the quality improved significantly. Review agents need at least sonnet; Senna on opus catches subtle issues (race conditions, mutation bugs).

## Background agents are non-negotiable
Every agent launch must use run_in_background=true. Blocking the main thread while a subagent runs defeats the purpose of delegation. Added a PreToolUse hook to enforce this — the hook denies any Agent call without run_in_background set.

## Team agents coordinate better with explicit instructions
Telling agents to "message X directly if you find issues" and "coordinate with Y to split scope" produces better results than having the coordinator relay everything. Senna and Jhin coordinated their review split, and both messaged Viktor directly with bugs. Viktor fixed and they verified — all without Sona in the loop.

## 3 of 4 "missing" MCP tools already existed
Orianna's audit identified 4 missing wallet-studio MCP tools. Zilean found 3 already existed under different names. Always verify what exists before building. The naming mismatch (upload_asset vs walletstudio_upload_asset) caused the false gap.

## Sequential team dependencies work well
Ekko researches → Azir/Lux design in parallel → Jayce/Viktor/Zilean implement in parallel → Senna/Jhin review. Each layer waits for its inputs via TaskList status checks. The full cycle from research to reviewed PR took ~20 minutes.
