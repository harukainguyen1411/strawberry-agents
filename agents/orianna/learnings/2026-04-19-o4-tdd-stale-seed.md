---
task: O4.2
type: xfail-seed
purpose: >
  TDD seed for orianna-memory-audit.sh (O4.2). Plants a known-stale claim
  so the first manual audit run can be verified to flag it.
  This file itself is a learnings entry; the stale claim is below.
---

# O4.2 TDD seed — known-stale claim

This file seeds a claim that is intentionally stale. When
`scripts/orianna-memory-audit.sh` is first run, Orianna should flag the
following claim as a block-severity finding because the path does not exist:

> The migration output is committed at `scripts/migrate-hetzner-to-gce.sh`
> and the discord-relay service config lives at `apps/discord-relay/config/hetzner.json`.

**Verification:** Orianna should produce a block finding for:
- `scripts/migrate-hetzner-to-gce.sh` — path does not exist in this repo.
- `apps/discord-relay/config/hetzner.json` — path does not exist in strawberry-app.

Once the first audit run confirms these are flagged, this file can be updated
to remove the stale claims (reconciliation step 3) or left as an
acknowledged-stale historical note.

<!-- acknowledged-stale-pending: awaiting first audit run to confirm flagging -->
