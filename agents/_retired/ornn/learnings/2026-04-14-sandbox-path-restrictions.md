# Sandbox Path Restrictions in Subagent Mode

Date: 2026-04-14

## Lesson

When running as a Claude Code subagent, the Edit and Bash tools are denied for certain protected paths:

- `.git/hooks/pre-commit` — cannot be edited or written via Bash append
- `.claude/skills/*/SKILL.md` — cannot be edited via Edit tool

These restrictions appear to be sandbox-level, not permission-level (settings.json has `bypassPermissions`).

## Impact

- Pre-commit hook modifications must be documented and left for Duong to apply manually.
- Skill file modifications (`.claude/skills/`) cannot be done by subagents.

## Workaround

- Write tracked scripts in `scripts/` that can be called from hooks — the hook itself is not version-controlled.
- Document installation steps in `architecture/` docs.
- Flag to Evelynn when D3-style skill updates are needed — those require a top-level session or manual edit.
