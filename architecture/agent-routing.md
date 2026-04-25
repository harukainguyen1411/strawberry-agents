# Agent routing — coordinator dispatch reference

## 1. Purpose and when to use

Read this before any `Agent` dispatch where a plan path is in scope. This doc is the lookup table; the active gate that forces the lookup is the `_shared/coordinator-routing-check.md` include, sourced by Evelynn and Sona. Rationale and failure diagnosis are in `assessments/research/2026-04-25-coordinator-routing-discipline.md` (commit `4b0ab6cf`).

## 2. Lane lookup table

| Upstream plan `owner:` | Required impl-set |
|---|---|
| `swain` / `aphelios` / `xayah` | `{viktor, rakan}` (complex builder + complex test-impl) |
| `azir` / `kayn` / `caitlyn` | `{jayce, vi}` (normal builder + normal test-impl) |
| `karma` | `{talon}` (single quick-lane executor; no pair split) |
| `neeko` | `{seraphine}` (complex frontend impl) |
| `lulu` | `{soraka}` (normal frontend impl) |
| `lux` | special case — see §4 |
| `syndra` | special case — see §4 |
| `heimerdinger` | `{ekko}` (single-lane DevOps execution) |

## 3. Rule 12 sequencing — xfail-first

For any complex or normal impl-set whose row includes a test-impl agent (`rakan` for complex, `vi` for normal), that agent's xfail commit MUST land on the target branch before the builder's first impl commit. Same branch, sequential commits — not parallel worktrees, not different branches.

Enforcement: Rule 12 in repo-root `CLAUDE.md`, the pre-push hook (`scripts/hooks/pre-push`), and CI (`tdd-gate.yml`). Agents may never bypass.

## 4. Single-lane and self-dispatch exceptions

- **Heimerdinger → Ekko** — single DevOps lane, no test-impl pair; Ekko has no pair-mate row.
- **Senna + Lucian** — PR review pair; dispatched after merge-ready, not as impl agents.
- **Akali** — QA pre-PR; dispatched for UI/user-flow PRs per Rule 16, not as impl.
- **Camille** — advisory only; never an impl dispatch.
- **Orianna** — plan promotion gate; callable directly by coordinators per Rule 19.
- **Lux / Syndra (self-dispatch)** — AI/MCP research agents frequently land artifacts as direct edits by the author (memos, assessments). Routing them as "self-dispatch impl" in §2 would mislead. Treated as a special case: no lane check applies when the author and the impl agent are the same identity.

## 5. Dispatch checklist

Before any `Agent` tool call where a plan is cited or implied, answer all four:

1. What is the upstream plan's `owner:` field?
2. Given that owner, what is the required impl-set from §2?
3. Is the agent I am about to dispatch in that set?
4. If the set has a test-impl agent (`rakan` or `vi`), has its xfail commit already landed on the target branch?

If question 3 is no: stop, pick from the correct set.
If question 4 is no: dispatch the test-impl pair-mate first.

## 6. Rationale and references

The two failure modes motivating this doc are documented in `assessments/research/2026-04-25-coordinator-routing-discipline.md`: Error 1 (lane mismatch — Talon dispatched on a Swain plan) and Error 2 (pair-set incomplete — Viktor dispatched without Rakan's xfail commit). The existing `_shared/coordinator-intent-check.md` primitive handles intent deliberation one level up; this doc and its companion include handle dispatch-routing correctness. Agent-pair taxonomy source: `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md`.
