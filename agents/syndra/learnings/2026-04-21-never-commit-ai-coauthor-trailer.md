# Never Commit AI Co-Author Trailer

**Date:** 2026-04-21
**Agent:** Syndra
**Trigger:** Commit 663c274 landed on main with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` — required a revert + clean re-apply to fix.

## Rule

Global CLAUDE.md line 1 invariant (user's private global instructions):

> Never include AI authoring references in commits

This is not a soft preference. It is the first-listed rule and applies across every repo and every session.

## What Went Wrong

Syndra emitted a `Co-Authored-By:` trailer attributing authorship to the Claude model. This has happened at least twice. The trailer is injected automatically by some harness configurations and by Claude Code's default commit behavior — it must be explicitly suppressed.

## Required Behavior

Before finalizing any commit message, check:

1. Does the message contain `Co-Authored-By:`? If yes, remove the line.
2. Does the message contain any string matching `Claude`, `Anthropic`, or `noreply@anthropic.com` in a trailer position? If yes, remove it.
3. Commit message body may only reference human authors or be authorless.

## Recovery Cost

When an AI attribution trailer lands on main:
- Requires `git revert` (anti-commit on main)
- Requires `git cherry-pick --no-commit` + clean `git commit`
- Two noise commits added to history
- Push of two commits instead of zero

This is avoidable by inspecting the commit message before `git commit` runs.

## Enforcement

No automated hook currently blocks this — Syndra must self-enforce. The rule predates this repo and lives in `~/.claude/CLAUDE.md`, which is loaded for every session.
