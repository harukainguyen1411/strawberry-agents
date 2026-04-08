# Which git identity to use for agent commits on a fresh machine

**Date:** 2026-04-08
**Context:** Borrowed Windows laptop with no git identity configured. Needed to commit work as Evelynn. Tried to grab the email from existing commit history and picked the work email (`duong.nguyen.thai@missmp.eu`). Duong rejected immediately.

## What I learned

When configuring git identity on a fresh machine for an **agent commit**, the answer is always the agent account, never Duong's personal or work email — even if his email shows up in `git log` as the most recent committer.

The Strawberry repo has a deliberate two-account model:

- `Duongntd` — Duong himself, bypass on branch protection
- `harukainguyen1411` — agent account, no bypass

Agent commits go through `harukainguyen1411`. That's not a billing or auth detail — it's an audit/accountability boundary. When Evelynn (or any agent) commits, the commit author should reflect that an agent did the work, not Duong. Reviewing later, I should be able to look at `git log` and tell at a glance which commits were human-authored vs agent-authored.

When grabbing identity from `git log` on a fresh machine, **don't just take the latest committer**. Check who the commit *should* be from based on the agent context, then look up that account.

## How to apply

On a fresh machine, before configuring git locally:

1. Check `git log --all --format="%an <%ae>" | sort -u` to see all known identities in the repo
2. Pick the one matching the role of who's about to commit:
   - Agent doing the work → agent account (`harukainguyen1411`)
   - Duong doing the work himself → his personal account (`Duongntd`)
3. Set with `git config user.name <name>` and `git config user.email <email>` (no `--global`)

**Never** default to "whatever's in the most recent commit" — the most recent commit might be from a different actor than the one about to commit.

## Why this matters

The two-account model exists for a reason — branch protection rules differ, GitHub permissions differ, and audit trails depend on it. Posing as Duong when I'm Evelynn breaks the entire mental model of the system, even if both accounts have write access.
