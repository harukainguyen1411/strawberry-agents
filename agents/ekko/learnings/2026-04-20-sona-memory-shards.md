# 2026-04-20 — Sona memory shard system

## What was built
Ported the strawberry-agents / Evelynn "last-48h shard" memory pattern to Sona.

## Key decisions
- `sessions/` (consolidation input) and `last-sessions/` (session-end output) follow the Evelynn model exactly.
- `sona.md` already existed as a curated long-term memory file — the `<!-- sessions:auto-below -->` sentinel was appended after the last bullet so consolidated shards land below it without disturbing the hand-written content above.
- The consolidate script does NOT `git push` (workspace repo is local-first, unlike strawberry-agents which pushes to remote).
- `git -C "${REPO_ROOT}"` used throughout the script instead of `cd` to avoid shell-state issues.
- The filter script uses a pure Python mtime check — no GNU `find -mmin` needed, macOS-safe.
- `last-session.md` preserved as a dual-write target for backwards compat.

## Paths created
- `secretary/agents/sona/memory/last-sessions/` — per-session shard output dir
- `secretary/agents/sona/memory/sessions/` — staging dir for shards awaiting consolidation
- `secretary/agents/sona/memory/sessions/archive/` — post-consolidation archive
- `secretary/scripts/sona-memory-consolidate.sh`
- `secretary/scripts/sona-filter-last-sessions.sh`
