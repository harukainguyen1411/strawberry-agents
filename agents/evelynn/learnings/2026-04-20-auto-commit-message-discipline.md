# Auto-commit message discipline

**Date:** 2026-04-20 (S62)
**Triggered by:** Ekko's `chore: commit pre-lockdown working tree state` rolled unrelated PascalCase normalization work into an opaque commit. Duong: "wdym skim it? It is uncommitted work, should not be trash."

## The problem

Rule 1 (never leave work uncommitted before any git op that changes the working tree) forces executors to pick up whatever dirty files exist and commit them before proceeding with their own task. This is non-negotiable — other agents share the working tree and uncommitted work WILL be lost.

The failure mode is the commit *message*, not the commit itself. Messages like "pre-lockdown working tree state" or "commit before moving file" describe the timing/reason for the commit, not the content. Future-me reading the git log has no idea what was in that commit without running `git show`.

## Discipline

When an executor auto-commits dirty files under Rule 1, the message body MUST describe what's actually in the diff, not why the commit was necessary. If the executor doesn't have time to read the diff before committing, they should at minimum name the modified files and their apparent theme.

**Bad:**
```
chore: commit pre-lockdown working tree state
```

**Good:**
```
chore: pre-op commit — sona/evelynn name PascalCase across sona.md + settings.json + aliases.sh

Picked up uncommitted changes from prior session before proceeding with
<current-task>. Diff is PascalCase normalization of agent name fields.
```

## Remediation pattern when it happens anyway

Use an **annotation commit** on top of the opaque one:
```
git commit --allow-empty -m "chore: annotate <sha> contents

Commit <sha> had a misleading title. Actual changes:
- <file>: <what changed>
- <file>: <what changed>
..."
```

This preserves the history (Rule prefers new commits over amends) and makes future git log readable. Precedent: `b5c5fea` annotates `387ef2a`.

## Coordinator responsibility

When dispatching an executor whose task will touch dirty files or trigger an auto-commit, include in the prompt: "If you auto-commit dirty files under Rule 1 before starting, describe the actual diff in the commit message — not the timing."
