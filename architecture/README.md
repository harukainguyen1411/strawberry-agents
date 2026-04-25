# Architecture — Strawberry

## §7.1 Canonical-folder rule

**If it's in `architecture/agent-network-v1/`, it's law.**
Authoritative description of how the v1 agent system works. Drift from operational reality is a bug to be fixed at the next observation.

**If it's elsewhere under `architecture/` (e.g. `apps/`), it's research, app-domain, or experimental.**
Not authoritative for the agent network. Subject to looser drift tolerance.

**If it's under `architecture/archive/`, it's historical record.**
Read-only; never edited except to correct archive-marker metadata.

## §7.2 Author discipline — adding new architecture docs

- New docs about the **agent network** MUST land directly under `architecture/agent-network-v1/`, not at the `architecture/` root.
- New docs about **application-domain concerns** (deploy targets, hosting, CORS, infra) land under `architecture/apps/`.
- Any plan whose `architecture_changes:` frontmatter points to a path outside `agent-network-v1/` must include a one-sentence justification in the plan body (e.g. "this is app-domain not agent-network").
- Do not create new files at the `architecture/` root. The root surface is intentionally thin: this `README.md` and the cornerstone `canonical-v1.md` (once it ships).

## §7.3 Index

### Canonical — agent network (source of truth)

`architecture/agent-network-v1/` — see [`agent-network-v1/README.md`](agent-network-v1/README.md) for the full file index and canonical-folder policy.

### App-domain

`architecture/apps/` — application-domain knowledge: deploy flows, hosting config, infrastructure.
See [`apps/README.md`](apps/README.md).

### Historical record

`architecture/archive/` — retired docs, stale regimes, and research artifacts.
See [`archive/README.md`](archive/README.md).

### Lock manifest

`architecture/canonical-v1.md` — SHA-pinned lock manifest (created by the retrospection-dashboard-and-canonical-v1 plan; not yet present in Wave 0).
