# agent-network-v1 — canonical architecture

This folder is the v1 canonical heart of the Strawberry agent system.
Every file here is **law**: authoritative description of how the system works as of v1.
Drift from operational reality is a bug; file an issue or fix it.

Edits to files in this folder during measurement-week (while `architecture/canonical-v1.md`
is active) require a `Lock-Bypass: <reason>` trailer in the commit message.

## Canonical files

The files below are the v1 source of truth. Files marked `[placeholder]` will land in W1/W2
of the architecture-consolidation plan (`plans/approved/personal/2026-04-25-architecture-consolidation-v1.md`).

| File | Covers |
|---|---|
| `overview.md` | System overview — current roster pointer, high-level agent flow `[placeholder — lands W2]` |
| `agents.md` | 30-line roster + role table; defers depth to `taxonomy.md` `[placeholder — lands W2]` |
| `taxonomy.md` | Agent-pair taxonomy — full pair-mapping matrix `[placeholder — lands W1]` |
| `routing.md` | Routing lookup table — which agent handles which dispatch `[placeholder — lands W1]` |
| `communication.md` | Agent communication protocols and contracts; live roster at `agents/memory/agent-network.md` `[placeholder — lands W2]` |
| `coordinator-boot.md` | Coordinator boot sequence and session identity `[placeholder — lands W1]` |
| `coordinator-memory.md` | Coordinator memory model and consolidation flow `[placeholder — lands W1]` |
| `compact-workflow.md` | `/compact` and `/pre-compact-save` mechanics `[placeholder — lands W1]` |
| `plan-lifecycle.md` | Plan lifecycle — proposed → approved → in-progress → implemented → archived `[placeholder — lands W1]` |
| `plan-frontmatter.md` | Plan YAML frontmatter fields (v2 fields only — v1 Orianna-gate fields archived) `[placeholder — lands W2]` |
| `git-workflow.md` | Commit-prefix policy (Rule 5), worktree discipline, branch protection `[placeholder — lands W2]` |
| `git-identity.md` | Git identity enforcement — three-layer model `[placeholder — lands W1]` |
| `pr-rules.md` | PR rules — review accounts, QA gate (Rule 16), work-scope anonymity `[placeholder — lands W2]` |
| `cross-repo.md` | Cross-repo workflow — strawberry-agents ↔ strawberry-app ↔ mmp `[placeholder — lands W1]` |
| `key-scripts.md` | Key scripts index — what each script does and when to use it `[placeholder — lands W1]` |
| `platform-parity.md` | Platform parity contract — Mac/Windows/GCE equivalence `[placeholder — lands W1]` |
| `platform-split.md` | Platform-split policy — what lives in `scripts/mac/` vs `scripts/windows/` `[placeholder — lands W1]` |
| `plugins.md` | Plugin list — current active Claude Code plugins `[placeholder — lands W1]` |
| `testing.md` | TDD enforcement — Rule 12–15, xfail discipline, test gate mechanics `[placeholder — lands W1]` |
| `security-debt.md` | Outstanding security debt — current known gaps `[placeholder — lands W1]` |

## §7.2 Author discipline (scoped to this folder)

- Every file added here must describe a **current, accurate** aspect of the v1 system.
- If the content is experimental, exploratory, or about an app-domain concern, it does NOT belong here.
- If you are retiring a file from this folder, move it to `architecture/archive/<tag>/` with a §5.4 archive-marker stamp at the top of the archived file and a `Supersedes:` line in the replacement file.
- Live roster data lives at `agents/memory/agent-network.md` (agent-owned); architecture protocol docs live here.
