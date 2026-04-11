# Rules need hooks — written rules alone aren't enforcement

**Date:** 2026-04-11
**Session:** S34

Written rules in CLAUDE.md or agent definitions are guidance, not enforcement. A model can drift from them under pressure or simply forget. For behavioral constraints that matter (e.g. "always run in background", "only spawn X"), wire a PreToolUse hook in settings.json that actually blocks the violation at the harness level.

The background-only Agent hook added this session demonstrated the principle immediately — it caught a foreground spawn before it fired.

**Caveat:** Hooks are global (apply to all sessions including Evelynn). For asymmetric rules (subagents only, not Evelynn), hook-level enforcement requires session context detection that Claude Code doesn't currently expose. In that case, written rules + instruction reinforcement in agent definitions is the best available option — but flag it as soft enforcement.
