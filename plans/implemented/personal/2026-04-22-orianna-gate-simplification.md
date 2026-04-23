---
status: implemented
complexity: quick
owner: karma
title: Orianna v2 — agent-gated plan promotions (simplification)
slug: 2026-04-22-orianna-gate-simplification
date: 2026-04-22
created: 2026-04-22
concern: personal
tests_required: true
---

## Context

The current Orianna gate is ceremonial overkill. Body-hash signatures, carry-forward verification, snapshot/restore traps, fact-check artifacts, and the `orianna_gate_version: 2` frontmatter regime collectively cost minutes per promotion and have produced a trail of 54 plans encumbered with signature metadata and hundreds of fact-check artifacts. Duong's explicit design: Orianna is just an agent. She says yes or no. If yes, she appends a cosmetic signature block and moves the file. Done.

New regime:
- Orianna becomes a **callable** opus agent at the path `.claude/agents/orianna.md`. <!-- orianna: ok -- prospective path, created by this plan --> Her job: read the plan, render APPROVE or REJECT for the requested stage transition. On APPROVE she appends a cosmetic signature block (human-readable date, agent name, stage transition — no body checksum), `git mv`s the plan to the target stage folder, commits with a `Promoted-By: Orianna` trailer, and pushes.
- Authorization is enforced at the **PreToolUse hook layer** (not the commit layer): the single guard at `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` fires before any Bash/Write/Edit/NotebookEdit tool execution and rejects — exit code 2 — any attempt to move, create, or overwrite files under protected plan-lifecycle directories unless the calling agent is Orianna. This is a physical-prevention layer; commit-phase guards are the wrong layer because identity is cheaply spoofable once the filesystem move has already happened.
- Signature scripts, verification scripts, the legacy `scripts/plan-promote.sh` promoter, the body-hash guard, the signature guard, and the fact-check generator are archived under `scripts/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> and `scripts/hooks/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan -->. One-shot sweep strips `orianna_gate_version` and existing signature blocks from current plans (cosmetic cleanup only; plans stay in place).
- the `assessments/plan-fact-checks` directory <!-- orianna: ok -- existing directory path, not a file --> is frozen — historical artifacts preserved, no new writes.

## Implementation divergence

An earlier draft of this plan described a commit-phase enforcement approach (pre-commit-plan-promote-guard.sh <!-- orianna: ok -- archived script, never fully wired --> + _orianna_identity.txt <!-- orianna: ok -- never created; design was abandoned --> + commit-msg-plan-promote-guard.sh <!-- orianna: ok -- archived script, never fully wired --> + `Promoted-By:` trailer verification). During execution this approach was replaced by a **PreToolUse physical-prevention layer** before any commit-phase work landed. The physical guard was delivered in full by PR #31 (merged 2026-04-23) with identity-propagation fixes by PR #32 (merged 2026-04-23). The commit-phase design was never wired. The canonical reference for the physical guard design is `plans/implemented/personal/2026-04-23-plan-lifecycle-physical-guard.md`.

## Risks to weigh before promoting

1. **Trailer forgery** — the commit-phase approach that required a `Promoted-By: Orianna` trailer was abandoned precisely because the trailer is spoofable. The physical guard at the PreToolUse layer prevents the filesystem move from occurring at all for non-Orianna agents, making trailer forgery moot.
2. **Git identity drift** — if Orianna's session git config is not set, her own commits will be rejected. T5 adds a bootstrap step in her agent definition to set `user.email` / `user.name` from a committed config snippet on every session start. <!-- orianna: ok -- git config key tokens, not file paths -->
3. **Other agents bypassing Orianna by editing her agent file** — agent def files live in `.claude/agents/` which is already covered by the existing hook surface; consider whether `.claude/agents/orianna.md` itself should require admin authorship to modify. Recommend: yes, add to hook's admin-only path list (T4.c). <!-- orianna: ok -- prospective path, created by this plan -->
4. **Legacy signatures in frozen plans** — approved/in-progress/implemented plans carry old signature blocks. Stripping them is cosmetic but touches many files; one atomic sweep commit is cleanest. No functional risk — nothing reads those blocks after the verify script is deleted.
5. **Orianna promotion atomicity** — if Orianna's `git mv` + commit succeeds but push fails, the plan is moved locally but unpushed. Same failure mode as today's archived `plan-promote.sh`; not a regression. Orianna's prompt should retry push on transient failure and surface hard failures to the caller. <!-- orianna: ok -- existing script referenced by name for context, not a prospective path -->
6. **No more fact-check paper trail** — historical assessments remain, but APPROVE decisions are now ephemeral (only the cosmetic signature block survives). If audit trail matters, Orianna's approval rationale can be captured in the commit message body. Recommend enforcing minimum commit body length for promotion commits (T4.d, optional).

## Tasks

- T1. **Relocate and rewrite Orianna agent definition.**
  Kind: edit. Estimate_minutes: 20.
  Files: `.claude/agents/orianna.md` (new) <!-- orianna: ok -- prospective path, created by this plan -->, `.claude/_script-only-agents/orianna.md` (delete).
  Detail: Create callable agent def with `model: opus` frontmatter and `tools: Read, Bash, Edit` (needs git mv + commit + push access). Prompt steps:
  - bootstrap git identity from `agents/orianna/memory/git-identity.sh` on session start <!-- orianna: ok -- prospective path, created by this plan -->
  - read the target plan file and the requested stage transition from the caller
  - render APPROVE or REJECT with a short rationale
  - on APPROVE: append a `## Orianna approval` block with date + agent name + from-stage + to-stage, update `status:` frontmatter, `git mv` the file to the new stage folder, commit with `Promoted-By: Orianna` trailer and rationale in body, then push
  - delete the script-only version
  DoD: Orianna is listed in `agents/memory/agent-network.md` as callable; `.claude/_script-only-agents/orianna.md` <!-- orianna: ok -- deleted by this plan --> removed; bootstrap script exists and sets a dedicated git identity.

- T2. **Archive retired scripts.**
  Kind: move. Estimate_minutes: 10.
  Files: `scripts/orianna-sign.sh` <!-- orianna: ok -- archived, moved to scripts/_archive/v1-orianna-gate/ -->, `scripts/orianna-verify-signature.sh` <!-- orianna: ok -- archived -->, `scripts/orianna-hash-body.sh` <!-- orianna: ok -- archived -->, `scripts/orianna-fact-check.sh` <!-- orianna: ok -- archived -->, `scripts/plan-promote.sh` <!-- orianna: ok -- archived -->, `scripts/_lib_orianna_gate_implemented.sh` <!-- orianna: ok -- archived -->, `scripts/_lib_orianna_gate_inprogress.sh` <!-- orianna: ok -- archived`, and their paired `test-orianna-*.sh` siblings (keep `scripts/orianna-memory-audit.sh`, `scripts/orianna-pre-fix.sh`, `scripts/_lib_orianna_architecture.sh`, `scripts/_lib_orianna_estimates.sh` — those are orthogonal to the gate).
  Detail: Move (not delete): old scripts move to `scripts/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> preserving filenames. Use `git mv` so history follows. Audit each script for cross-references before moving; `grep -rn <script-name>` across repo. Update any caller that still invokes them.
  DoD: No active code references to the archived scripts remain in `scripts/` (outside `_archive/`), `.claude/`, `architecture/` (outside `archive/`), or `CLAUDE.md`; `scripts/test-hooks.sh` still green; archived scripts present under `scripts/_archive/v1-orianna-gate/`. <!-- orianna: ok -- prospective archive path, created by this plan -->

- T3. **PreToolUse physical-prevention gate (superseded the earlier pre-commit design).**
  Kind: impl. Estimate_minutes: 30.
  Files: `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` (new), `.claude/settings.json` (update), `scripts/hooks/_lib_bash_path_scan.py` (new), `scripts/hooks/requirements.txt` (new).
  **Shipped:** PR #31 (merged 2026-04-23). Identity-propagation fix: PR #32 (merged 2026-04-23).
  Detail:
  - Single POSIX-portable bash script at `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`. <!-- orianna: ok -- prospective path, created by this plan --> Reads hook payload JSON from stdin; dispatches on `.tool_name`.
  - **Bash tool**: extracts the `.tool_input.command` field <!-- orianna: ok -- JSON field name, not a file path -->; applies a fast pre-filter (skip if command contains no `plans` substring); delegates to `scripts/hooks/_lib_bash_path_scan.py` (a bashlex 0.18 AST walker) to detect mutating operations (verb allowlist: mv, cp, rm, touch, tee, dd, install, rsync, truncate, mkdir, rmdir, plus git subverbs mv and rm) that reference protected plan paths. Fail-closed on bashlex parse errors or missing python3.
  - **Write/Edit/NotebookEdit tools**: extracts `.tool_input.file_path` or `.tool_input.notebook_path`; normalizes to repo-relative; checks against protected roots. Edit and NotebookEdit on existing files are always permitted (edit-only permission shape). Write on an existing file (overwrite) is permitted. Write creating a new file in a protected directory is blocked.
  - **Identity resolution** (in order): framework `.agent_type` field in the hook JSON payload (set by Claude Code for Agent-tool subagent calls) → `$CLAUDE_AGENT_NAME` env var → `$STRAWBERRY_AGENT` env var → fail-closed.
  - **Admin bypass**: Duong's admin identities (`harukainguyen1411`, `Duongntd`) are authorized via `scripts/orianna-bypass-audit.sh` (post-hoc audit). The guard itself recognizes only `orianna` (case-insensitive) at the PreToolUse layer. No `Orianna-Bypass:` trailer mechanism; no _orianna_identity.txt file <!-- orianna: ok -- this file was never created; design was abandoned -->.
  - `.claude/settings.json` registers two `PreToolUse` matchers: one for `Bash` and one for `Write|Edit|NotebookEdit`, both pointing at the same script. Single source of truth; no second file to drift.
  - Post-hoc audit at `scripts/orianna-bypass-audit.sh` — non-blocking; detects orphan plans (plans in protected directories not introduced by an authorized identity) after the fact.
  DoD: shellcheck clean; both matchers wired in settings.json; unit tests in `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` green.

- T4. **Cosmetic cleanup of hook directory.**
  Kind: edit. Estimate_minutes: 30.
  Files: pre-commit-plan-promote-guard.sh <!-- orianna: ok -- archived hook, may or may not exist --> (archive), pre-commit-orianna-body-hash-guard.sh <!-- orianna: ok -- archived hook --> (archive), pre-commit-orianna-signature-guard.sh <!-- orianna: ok -- archived hook --> (archive), test-pre-commit-orianna-signature.sh <!-- orianna: ok -- archived test --> (archive), `scripts/install-hooks.sh` (update). All of these live under `scripts/hooks/`. <!-- orianna: ok -- existing directory, not a file -->
  Archive destination: `scripts/hooks/_archive/v2-commit-phase-plan-guards/`. <!-- orianna: ok -- prospective path, created by this plan -->
  Detail: git mv all four hooks and their tests to the archive directory; update `scripts/install-hooks.sh` to drop all references to the archived scripts; grep the tree for remaining references outside the archive subtree. The commit-phase plan-promote guards (pre-commit-plan-promote-guard.sh <!-- orianna: ok -- archived hook --> and commit-msg-plan-promote-guard.sh <!-- orianna: ok -- archived hook -->) are archived because the physical-prevention layer at PreToolUse makes them redundant and they could not prevent identity spoofing anyway.
  DoD: `scripts/install-hooks.sh` does not reference archived script names; `scripts/hooks/test-hooks.sh` runs clean.

- T5. **Orianna git identity bootstrap.**
  Kind: create. Estimate_minutes: 10.
  Files: `agents/orianna/memory/git-identity.sh` (new). <!-- orianna: ok -- prospective path, created by this plan -->
  Detail: `git-identity.sh` sets `git config user.email orianna@strawberry.local` and `user.name "Orianna"` in the current worktree. Orianna's agent prompt invokes the script on every session start. <!-- orianna: ok -- bare script names here are described by full paths on the Files: line above -->
  DoD: Running the script sets expected values; Orianna agent def references the script.

- T6. **Rewrite CLAUDE.md Rule 19 and architecture docs.**
  Kind: edit. Estimate_minutes: 15.
  Files: `CLAUDE.md`, `architecture/plan-lifecycle.md`, `architecture/key-scripts.md`.
  **Shipped:** CLAUDE.md Rule 19 and Rule 7 updated to reference the PreToolUse guard as the enforcement mechanism (no `Promoted-By:` trailer verification, no _orianna_identity.txt <!-- orianna: ok -- was never created -->). `architecture/plan-lifecycle.md` updated to describe the physical-prevention layer.
  Detail: Rule 19 describes: Orianna is a callable agent. Only she (and Duong's admin identities) may commit plan moves out of the proposed stage (plans/proposed/ <!-- orianna: ok -- existing directory -->); enforced by the single PreToolUse guard at `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`. No `Orianna-Bypass:` trailer mechanism; no _orianna_identity.txt file <!-- orianna: ok -- was never created -->. Identity resolved via framework `agent_type` → `CLAUDE_AGENT_NAME` → `STRAWBERRY_AGENT` → fail-closed. Update `plan-lifecycle.md` to describe the new flow (caller → Orianna agent → commit) and add a "Physical enforcement" subsection. Update `key-scripts.md` to remove archived script entries. Archive the relevant section(s) of `architecture/key-scripts.md` under `architecture/archive/v1-orianna-gate/key-scripts-excerpt.md`. <!-- orianna: ok -- prospective archive path, created by this plan -->
  DoD: No references to `orianna-sign.sh`, `plan-promote.sh`, `orianna_gate_version`, `Orianna-Bypass:` trailer, or `_orianna_identity.txt` remain in `CLAUDE.md` or `architecture/`; archived copies exist under `architecture/archive/v1-orianna-gate/`. <!-- orianna: ok -- prospective archive path, created by this plan -->

- T7. **Retire fact-check generator path.**
  Kind: edit. Estimate_minutes: 5.
  Files: any cron/hook/script that writes to the `assessments/plan-fact-checks` directory <!-- orianna: ok -- existing directory path, not a file -->.
  Detail: Disable generation; leave existing artifacts untouched. Add a `README.md` in the folder noting the freeze date. <!-- orianna: ok -- prospective file to be created by this task -->
  DoD: No code path writes new files under the `assessments/plan-fact-checks` directory <!-- orianna: ok -- existing directory path, not a file -->; historical files preserved.

- T8. **Hook authorization tests**
  Kind: test. Estimate_minutes: 30.
  Files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` (new). <!-- orianna: ok -- prospective path, created by this plan -->
  **Shipped:** 37 test assertions in `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` (PR #31 + PR #32). Covers:
  - INV-1..INV-6: core identity/path invariants (ekko→exit 2, orianna→exit 0, no-identity→exit 2 fail-closed, etc.)
  - C1/C1b/C2/C3/C4: Senna bypass-vector cases (single-quote, double-quote, double-slash, dot-dot traversal, malformed JSON)
  - File-existence semantics for Write/Edit/NotebookEdit (new file in protected dir blocked; existing file edit permitted)
  - R2: AST walker cases (case-fold bypass, chained command, variable assignment, tee redirect, missing python3 fail-closed)
  - R3: structural AST walker fixes (grep/cat/ls on plan paths do not block; sed -i on plan path blocks)
  - V: verb-allowlist tests (read-only verbs on plan paths pass; redirect-write to protected path blocks)
  - A1/A2: agent_type identity propagation (framework-injected field takes precedence over env vars)
  Tests are registered in `scripts/hooks/test-hooks.sh`.
  DoD: All 37 assertions pass.

## Test plan

Invariants the tests must protect:

1. **Only Orianna can move plans out of the proposed stage** — the PreToolUse guard fires before the Bash tool executes and rejects a git mv from plans/proposed/personal/foo.md <!-- orianna: ok -- hypothetical fixture path --> to plans/approved/personal/foo.md <!-- orianna: ok -- hypothetical fixture path --> when `CLAUDE_AGENT_NAME=ekko` (exit 2); accepts when identity resolves to `orianna` (exit 0).
2. **No identity env var → fail-closed** — guard rejects a protected-path operation when neither `.agent_type` nor `$CLAUDE_AGENT_NAME` nor `$STRAWBERRY_AGENT` is set (exit 2).
3. **Non-promotion commits cannot create plans in non-proposed stages** — Write tool targeting a new file under plans/approved/ <!-- orianna: ok -- existing protected directory --> or plans/in-progress/ <!-- orianna: ok -- existing protected directory --> with a non-Orianna agent identity is blocked (exit 2).
4. **Sweep script idempotence** — run T3's one-shot cleanup sweep twice; second run produces zero diff.
5. **Lifecycle smoke** — end-to-end: Orianna agent (invoked via Agent-tool subagent call) approves a proposed plan; the framework injects `agent_type=orianna` into the PreToolUse hook payload; the move + commit lands cleanly.
6. **Read-only operations on protected paths are never blocked** — `git add`, `cat`, `ls`, `grep` on plan paths under protected directories exit 0 regardless of agent identity (verb-allowlist in AST walker).

All tests live in `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` and are wired into `scripts/hooks/test-hooks.sh`.

## References

- `CLAUDE.md` Rule 19 (updated to describe PreToolUse physical guard)
- `architecture/plan-lifecycle.md` (to be updated with physical enforcement subsection)
- `plans/implemented/personal/2026-04-23-plan-lifecycle-physical-guard.md` (canonical implementation plan for T3)
- `plans/implemented/2026-04-20-orianna-gated-plan-lifecycle.md` (origin of v2 regime — historical context only)
- `.claude/agents/orianna.md` (callable agent def, created by T1)
- `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` (shipped by PR #31)
- `scripts/hooks/_lib_bash_path_scan.py` (bashlex AST walker, shipped by PR #31)
- `scripts/orianna-bypass-audit.sh` (post-hoc audit script, shipped by PR #31)
- `scripts/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> (destination for archived v1 scripts)

## Orianna approval

- date: 2026-04-23
- agent: orianna
- from-stage: in-progress
- to-stage: implemented
- verdict: APPROVE
- rationale: All load-bearing claims verified against repo state. pretooluse-plan-lifecycle-guard.sh exists and ships identity resolution chain (agent_type → CLAUDE_AGENT_NAME → STRAWBERRY_AGENT → fail-closed). Test file exists with 47 assertion lines. PR #31 and PR #32 both MERGED 2026-04-23. Archive dirs exist. CLAUDE.md Rule 19 and architecture/plan-lifecycle.md updated. Canonical physical-guard plan exists at plans/implemented/personal/. Implementation complete.
