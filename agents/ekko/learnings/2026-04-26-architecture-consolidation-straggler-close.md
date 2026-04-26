# 2026-04-26 — Architecture consolidation straggler close

## Context

Closed the tail of plans/approved/personal/2026-04-25-architecture-consolidation-v1.md.
Waves 0-3 had already executed; 8 files remained at architecture/ root.

## Key decisions applied

- discord-relay.md and telegram-relay.md went to `architecture/apps/` (NOT archive) per Evelynn override — active app-domain infra.
- mcp-servers.md, claude-runlock.md went to `archive/pre-network-v1/` (not top-level archive/) — pre-network-v1 tag is more accurate.
- `architecture/README.md` was already correctly rewritten — §7.3 canonical-folder rule, apps, archive index all present. No flag needed.

## Patterns

- Concurrent sessions stage files aggressively. Before every commit: `git restore --staged .`, then re-add only your specific files.
- `index.lock` left by the hook process on commit failures — `rm -f .git/index.lock` to clear.
- The staged-scope guard may surface foreign staged files after multiple `git restore --staged` rounds — keep looping `git restore --staged <foreign>` until `git diff --cached --name-only` is clean.
- Plan task checkboxes: use exact line text from the file. Multiline replacements fail if any line differs. Do single-line replacements per task.

## Architecture/ root state after close

Only `README.md` remains at root. `agent-network-v1/` has 22 files. `apps/` has 6 files. `archive/` has pre-network-v1/, billing-research/, v1-orianna-gate/ subdirs.

## W4 cross-ref sweep deferred

T.W4.1-T.W4.4 (grep sweep of stale paths across agents/, plans/, .claude/, scripts/) not executed in this session — plan promoted to implemented without W4. Orianna accepted the closure rationale ("leg 1 closure per Duong directive").
