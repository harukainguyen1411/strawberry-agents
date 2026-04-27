# agents/_state/

Schema migration files for the coordinator state store (coordinator-memory-v1).

**Runtime DB location:** `~/.strawberry-state/state.db` (gitignored, outside repo tree).
See ADR §D2 for rationale — the repo lives under iCloud Drive; SQLite WAL files corrupt under iCloud sync.

**Schema is committed here; runtime DB is not.**

## Migrations

| File | Description |
|------|-------------|
| `0001-init.sql` | Initial schema — 10 tables (§D3 of the ADR) |

Apply via: `sqlite3 ~/.strawberry-state/state.db < agents/_state/migrations/0001-init.sql`

For new-machine bootstrap or disaster recovery, run `scripts/state/rebuild.sh` (T10b).

ADR reference: `plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md`
