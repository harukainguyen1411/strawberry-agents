# Playwright MCP — video recording is a tool call, not a flag

**Date:** 2026-04-21
**Session:** 0cf7b28e (S65)

## Lesson

Playwright MCP does not support `--save-video=on` as an always-on flag. Video recording is gated behind the `devtools` capability, which exposes `browser_start_video` and `browser_stop_video` as callable tools. An agent must explicitly call `browser_start_video` at the start of a QA run and `browser_stop_video` at the end.

"Default video recording" in practice means the tools are available by default in the agent's tool set — the agent must still invoke them. Add `browser_start_video` as the mandatory first step in every Akali QA session instruction.

## Application

Any delegation to Akali that says "record video" needs to explicitly instruct her to call `browser_start_video` first. Lux's survey memo (`assessments/mcp-ecosystem/2026-04-21-playwright-browser-mcp-survey.md`) has full tool catalog.
