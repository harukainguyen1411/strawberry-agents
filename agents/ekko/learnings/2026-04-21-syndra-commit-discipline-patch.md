# 2026-04-21 — Syndra commit-discipline patch

## Problem
Syndra was appending `Co-Authored-By: Claude …` trailers to commits, violating the global
"Never include AI authoring references in commits" rule in `~/.claude/CLAUDE.md`. The global
CLAUDE.md is NOT reliably inherited by subagent boots — agent-specific defs must carry the rule.

## Fix
Added a `## Commit discipline (CRITICAL)` section to `.claude/agents/syndra.md`, placed
immediately after the frontmatter block (before any other `#` heading). 9-line insert.

## Pattern
For any agent that keeps adding AI-coauthor footers, the fix is a top-of-body CRITICAL section
in that agent's `.md` def. The section must:
1. Name the exact strings to never include.
2. Cover git commit, --amend, and PR bodies.
3. Reference the in-flight hook plan for traceability.

## Commit
a56a25d — chore: remind syndra no AI coauthor lines in commits (no Co-Authored-By trailer).
