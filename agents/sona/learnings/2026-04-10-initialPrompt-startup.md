# 2026-04-10 — Use initialPrompt for reliable agent startup

## Problem
Agent body text (markdown below frontmatter) becomes system prompt. Models treat system prompt instructions as optional — especially Sonnet, which cuts corners on multi-step sequential reads. Putting "read these 6 files in order" in the body resulted in skipped files.

## Fix
Use the `initialPrompt` frontmatter field. It auto-submits as the first user turn when the agent is the main session agent (via `"agent"` in settings.json). Models comply with user instructions at much higher rates than system prompt suggestions.

## Also
- `"agent": "sona"` in settings.json makes every workspace session start as Sona
- The `model` field in agent frontmatter is overridden by `model` in settings.json for the main agent — it only applies when the agent runs as a subagent
- `disable-model-invocation: true` on skills prevents auto-invocation but also blocks natural language triggers like "end session" — keep it false and rely on description text instead
