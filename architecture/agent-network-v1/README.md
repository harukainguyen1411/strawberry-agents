# agent-network-v1 — canonical architecture

This folder is the v1 canonical heart of the Strawberry agent system.
Every file here is **law**: authoritative description of how the system works as of v1.
Drift from operational reality is a bug; file an issue or fix it.

Edits to files in this folder during measurement-week (while `architecture/canonical-v1.md`
is active) require a `Lock-Bypass: <reason>` trailer in the commit message.
See `git-workflow.md` §Lock-Bypass contract for the full protocol.

## Canonical files

| File | Covers |
|---|---|
| `overview.md` | System overview — current roster pointer, two-repo structure, design principles |
| `agents.md` | 30-line roster + role table; defers depth to `taxonomy.md` |
| `taxonomy.md` | Agent-pair taxonomy — full track model and role-slot matrix |
| `routing.md` | Routing lookup table — which agent handles which dispatch |
| `communication.md` | Agent communication protocols and contracts; live roster at `agents/memory/agent-network.md` |
| `coordinator-boot.md` | Coordinator boot sequence and session identity |
| `coordinator-memory.md` | Coordinator memory model and consolidation flow |
| `compact-workflow.md` | `/compact` and `/pre-compact-save` mechanics |
| `plan-lifecycle.md` | Plan lifecycle — proposed → approved → in-progress → implemented → archived |
| `plan-frontmatter.md` | Plan YAML frontmatter fields (v2 fields only — v1 Orianna-gate fields archived) |
| `git-workflow.md` | Commit-prefix policy (Rule 5), worktree discipline, branch protection, Lock-Bypass contract |
| `git-identity.md` | Git identity enforcement — three-layer model |
| `pr-rules.md` | PR rules — review accounts, QA gate (Rule 16), work-scope anonymity, Rules 12/13/15/17/18/21 |
| `cross-repo.md` | Cross-repo workflow — strawberry-agents ↔ strawberry-app ↔ mmp |
| `key-scripts.md` | Key scripts index — what each script does and when to use it |
| `platform-parity.md` | Platform parity contract — Mac/Windows/GCE equivalence |
| `platform-split.md` | Platform-split policy — what lives in `scripts/mac/` vs `scripts/windows/` |
| `plugins.md` | Plugin list — current active Claude Code plugins |
| `testing.md` | TDD enforcement — Rule 12–15, xfail discipline, test gate mechanics |
| `security-debt.md` | Outstanding security debt — current known gaps |

## §7.2 Author discipline (scoped to this folder)

- Every file added here must describe a **current, accurate** aspect of the v1 system.
- If the content is experimental, exploratory, or about an app-domain concern, it does NOT belong here.
- If you are retiring a file from this folder, move it to `architecture/archive/<tag>/` with a §5.4 archive-marker stamp at the top of the archived file and a `Supersedes:` line in the replacement file.
- Live roster data lives at `agents/memory/agent-network.md` (agent-owned); architecture protocol docs live here.
