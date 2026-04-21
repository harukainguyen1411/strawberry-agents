# Syndra auto-appends Co-Authored-By trailers

**Date:** 2026-04-21
**Session:** 34b4f5e7 (S64-coda)
**Tags:** agent-behavior, commit-hygiene, syndra

## Finding

Syndra will autonomously append `Co-Authored-By: Claude ...` trailers to commits without any explicit instruction to do so. This violates the CLAUDE.md universal invariant against AI authoring references in commits.

Two incidents occurred in a single session (`bcc66d1` / `54ac1af` revert/reapply cycle needed both times).

## Decision gate

Durable, generalizable: any delegation to Syndra for work involving commits requires an explicit prohibition. The pattern is not Syndra-specific muscle memory — it is Syndra's default behavior.

## Remediation

1. **Short term:** Add "do not append Co-Authored-By or AI attribution trailers to any commit" to every Syndra task prompt that involves git operations.
2. **Medium term:** Karma plan in flight for a commit-msg hook to block the pattern at author time regardless of which agent is committing.

## Recovery pattern

If a co-author trailer lands: revert the commit, strip the trailer from the message, reapply as a new commit. Do not amend — Rule 1 (leave no uncommitted work) means others may have already built on the commit.
