---
status: approved
complexity: quick
owner: karma
title: Orianna v2 — agent-gated plan promotions (simplification)
slug: 2026-04-22-orianna-gate-simplification
date: 2026-04-22
created: 2026-04-22
orianna_gate_version: 2
concern: personal
tests_required: true
orianna_signature_approved: "sha256:9fe57cfd565c778eb5c863909d206ed92d81f7f3f2fb9356113ea6c244960a9f:2026-04-23T02:55:27Z"
---

## Context

The current Orianna gate is ceremonial overkill. Body-hash signatures, carry-forward verification, snapshot/restore traps, fact-check artifacts, and the `orianna_gate_version: 2` frontmatter regime collectively cost minutes per promotion and have produced a trail of 54 plans encumbered with signature metadata and hundreds of fact-check artifacts. Duong's explicit design: Orianna is just an agent. She says yes or no. If yes, she appends a cosmetic signature block and moves the file. Done.

New regime:
- Orianna becomes a **callable** opus agent at the path `.claude/agents/orianna.md`. <!-- orianna: ok -- prospective path, created by this plan --> Her job: read the plan, render APPROVE or REJECT for the requested stage transition. On APPROVE she appends a cosmetic signature block (human-readable date, agent name, stage transition — no hash), `git mv`s the plan to the target stage folder, commits with a `Promoted-By: Orianna` trailer, and pushes.
- Authorization is enforced at the pre-commit hook layer: any diff that moves a plan file out of the `plans/proposed/` subtree <!-- orianna: ok -- prospective path, created by this plan --> must either carry a `Promoted-By: Orianna` commit trailer AND have a commit author email matching the Orianna agent identity, or be authored by Duong's admin identity (`harukainguyen1411`). All other commits may only create files inside `plans/proposed/`. <!-- orianna: ok -- prospective path, created by this plan -->
- Signature scripts, verification scripts, the legacy `scripts/plan-promote.sh` promoter, the body-hash guard, the signature guard, and the fact-check generator are archived under `scripts/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> and `scripts/hooks/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan -->. One-shot sweep strips `orianna_gate_version` and existing signature blocks from current plans (cosmetic cleanup only; plans stay in place).
- the `assessments/plan-fact-checks` directory <!-- orianna: ok -- existing directory path, not a file --> is frozen — historical artifacts preserved, no new writes.

## Risks to weigh before promoting

1. **Trailer forgery** — any agent could write `Promoted-By: Orianna` into a commit message. Mitigation: pre-commit hook cross-checks the trailer against `git config user.email` at commit time. Orianna agent sessions must set a distinct git identity (e.g. `orianna@strawberry.local`). Pre-push hook re-verifies on push. Duong's admin identity remains the only human bypass.
2. **Git identity drift** — if Orianna's session git config is not set, her own commits will be rejected. T5 adds a bootstrap step in her agent definition to set `user.email` / `user.name` from a committed config snippet on every session start. <!-- orianna: ok -- git config key tokens, not file paths -->
3. **Other agents bypassing Orianna by editing her agent file** — agent def files live in `.claude/agents/` which is already covered by the existing hook surface; consider whether `.claude/agents/orianna.md` itself should require admin authorship to modify. Recommend: yes, add to hook's admin-only path list (T4.c). <!-- orianna: ok -- prospective path, created by this plan -->
4. **Legacy signatures in frozen plans** — approved/in-progress/implemented plans carry old signature blocks. Stripping them is cosmetic but touches many files; one atomic sweep commit is cleanest. No functional risk — nothing reads those blocks after the verify script is deleted.
5. **Orianna promotion atomicity** — if Orianna's `git mv` + commit succeeds but push fails, the plan is moved locally but unpushed. Same failure mode as today's `plan-promote.sh`; not a regression. Orianna's prompt should retry push on transient failure and surface hard failures to the caller. <!-- orianna: ok -- existing script referenced by name for context, not a prospective path -->
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
  DoD: Orianna is listed in `agents/memory/agent-network.md` as callable; `.claude/_script-only-agents/orianna.md` removed; bootstrap script exists and sets a dedicated git identity.

- T2. **Archive retired scripts.**
  Kind: move. Estimate_minutes: 10.
  Files: `scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`, `scripts/orianna-hash-body.sh`, `scripts/orianna-fact-check.sh`, `scripts/plan-promote.sh`, `scripts/_lib_orianna_gate_implemented.sh`, `scripts/_lib_orianna_gate_inprogress.sh`, and their paired `test-orianna-*.sh` siblings (keep `scripts/orianna-memory-audit.sh`, `scripts/orianna-pre-fix.sh`, `scripts/_lib_orianna_architecture.sh`, `scripts/_lib_orianna_estimates.sh` — those are orthogonal to the gate).
  Detail: Move (not delete): old scripts move to `scripts/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> preserving filenames. Use `git mv` so history follows. Audit each script for cross-references before moving; `grep -rn <script-name>` across repo. Update any caller that still invokes them.
  DoD: No active code references to the archived scripts remain in `scripts/` (outside `_archive/`), `.claude/`, `architecture/` (outside `archive/`), or `CLAUDE.md`; `scripts/test-hooks.sh` still green; archived scripts present under `scripts/_archive/v1-orianna-gate/`. <!-- orianna: ok -- prospective archive path, created by this plan -->

- T3. **One-shot plan cleanup sweep.**
  Kind: edit. Estimate_minutes: 15.
  Files: all files under `plans/**` that contain `orianna_gate_version` or `Orianna-Signature` (54 + 5 files per current grep). <!-- orianna: ok -- descriptive glob pattern, not a real path -->
  Detail: Script a sweep (`scripts/sweep-orianna-metadata.sh` — disposable, can live in `/tmp` or be deleted after use) that strips the `orianna_gate_version:` frontmatter line and any `## Orianna signature` blocks with their body. <!-- orianna: ok -- prospective disposable script, not a committed file --> Plans remain in their current stage folders. Commit as a single `chore:` commit.
  DoD: running grep recursively for `orianna_gate_version` and `Orianna-Signature` under the plans directory returns zero results.

- T4. **Rewrite pre-commit hook for plan-move authorization.**
  Kind: edit. Estimate_minutes: 30.
  Files: `scripts/hooks/pre-commit-plan-promote-guard.sh`, `scripts/hooks/pre-commit-orianna-body-hash-guard.sh` (archive to `scripts/hooks/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan -->), `scripts/hooks/pre-commit-orianna-signature-guard.sh` (archive to `scripts/hooks/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan -->), `scripts/hooks/test-pre-commit-orianna-signature.sh` (archive to `scripts/hooks/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan -->), `scripts/hooks/test-plan-promote-guard.sh` (rewrite).
  Detail:
  - Detect staged diff that moves (`R` status) or deletes files matching `plans/proposed/**` where the counterpart creates `plans/(approved|in-progress|implemented|archived)/**`. <!-- orianna: ok -- literal glob pattern in hook logic, not a real path -->
  - For such diffs, require commit author email to match the Orianna agent identity (exact string match against a committed allowlist in `scripts/hooks/_orianna_identity.txt`) AND require the commit message to contain a `Promoted-By: Orianna` trailer. <!-- orianna: ok -- prospective path, created by this plan --> Read the commit message from `$1` in the commit-msg hook, or use a two-stage check where pre-commit validates author + staged paths and commit-msg validates trailer.
  - Extend admin-only path list to include `.claude/agents/orianna.md` and `scripts/hooks/_orianna_identity.txt` so only Duong's admin identity may modify them. <!-- orianna: ok -- prospective paths, created by this plan -->
  - Optional: enforce minimum body length of at least thirty characters on promotion commits so approval rationale is preserved.
  - Non-promotion commits: reject any creation under `plans/approved/**`, `plans/in-progress/**`, `plans/implemented/**`, `plans/archived/**` unless author is Orianna or Duong's admin identity. <!-- orianna: ok -- literal glob patterns in hook logic, not real paths -->
  DoD: New unit tests pass; retired hooks and their tests moved to `scripts/hooks/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan -->; `install-hooks.sh` updated if it enumerates hook filenames.

- T5. **Orianna git identity bootstrap.**
  Kind: create. Estimate_minutes: 10.
  Files: `agents/orianna/memory/git-identity.sh` (new) <!-- orianna: ok -- prospective path, created by this plan -->, `scripts/hooks/_orianna_identity.txt` (new) <!-- orianna: ok -- prospective path, created by this plan -->.
  Detail: `git-identity.sh` sets `git config user.email orianna@strawberry.local` and `user.name "Orianna"` in the current worktree. `_orianna_identity.txt` contains the single-line canonical email the hook checks against. Orianna's agent prompt invokes the script on every session start. <!-- orianna: ok -- bare script names here are described by full paths on the Files: line above -->
  DoD: Running the script sets expected values; hook reads the identity file successfully.

- T6. **Rewrite CLAUDE.md Rule 19 and architecture docs.**
  Kind: edit. Estimate_minutes: 15.
  Files: `CLAUDE.md`, `architecture/plan-lifecycle.md`, `architecture/key-scripts.md`.
  Detail: Rule 19 becomes a short paragraph: Orianna is a callable agent. She decides plan promotions. Only she (and Duong's admin identity) may commit plan moves out of `plans/proposed/**`; enforced by pre-commit hook via author identity + `Promoted-By: Orianna` trailer. No signatures, no hashes, no fact-check artifacts. Remove the `Orianna-Bypass:` trailer mechanism — admin identity is the only bypass. Update `plan-lifecycle.md` to describe the new flow (caller -> Orianna agent -> commit). Update `key-scripts.md` to remove the archived script entries. Archive the current `architecture/plan-lifecycle.md` and the relevant section(s) of `architecture/key-scripts.md` under `architecture/archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> before rewriting. Preserve history via `git mv` for plan-lifecycle.md; for key-scripts.md extract the archived section into a standalone file in `architecture/archive/v1-orianna-gate/key-scripts-excerpt.md`. <!-- orianna: ok -- prospective archive path, created by this plan -->
  DoD: No references to `orianna-sign.sh`, `plan-promote.sh`, or `orianna_gate_version` remain in `CLAUDE.md` or `architecture/`; and archived copies exist under `architecture/archive/v1-orianna-gate/`. <!-- orianna: ok -- prospective archive path, created by this plan -->

- T7. **Retire fact-check generator path.**
  Kind: edit. Estimate_minutes: 5.
  Files: any cron/hook/script that writes to the `assessments/plan-fact-checks` directory <!-- orianna: ok -- existing directory path, not a file -->.
  Detail: Disable generation; leave existing artifacts untouched. Add a `README.md` in the folder noting the freeze date. <!-- orianna: ok -- prospective file to be created by this task -->
  DoD: No code path writes new files under the `assessments/plan-fact-checks` directory <!-- orianna: ok -- existing directory path, not a file -->; historical files preserved.

- T8. **Write hook authorization tests**
  Kind: test. Estimate_minutes: 30.
  Files: `scripts/hooks/test-orianna-gate-v2.bats` (new) <!-- orianna: ok -- prospective path, created by this plan -->
  Detail: Author bats tests exercising the 6 invariants listed in `## Test plan`:
  - Hook rejects non-Orianna identity on plan-lifecycle paths.
  - Hook accepts Orianna identity with valid signature trailer.
  - Hook respects `Orianna-Bypass:` trailer only when author is `harukainguyen1411`.
  - Archive path `scripts/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> retains files (no deletion).
  - `orianna_gate_version: 2` plans require full signature chain. <!-- orianna: ok -- frontmatter key token, not a path -->
  - Grandfathered plans (no `orianna_gate_version`) fall back to legacy fact-check. <!-- orianna: ok -- frontmatter key token, not a path -->
  Tests live under `scripts/hooks/test-orianna-gate-v2.bats` (create new file). <!-- orianna: ok -- prospective path, created by this plan -->
  DoD: All 6 tests pass under bats; wired into `scripts/hooks/test-hooks.sh`.

## Test plan

Invariants the tests must protect:

1. **Only Orianna or admin can move plans out of `proposed/`** — unit test in `scripts/hooks/test-plan-promote-guard.sh`: craft a staged diff that renames a `plans/proposed/personal/foo.md` to `plans/approved/personal/foo.md`; assert hook REJECTS when author email is a generic agent email AND no `Promoted-By` trailer is present; assert hook ACCEPTS when author email matches `_orianna_identity.txt` AND trailer is present; assert hook ACCEPTS when author email is `harukainguyen1411`'s admin address. <!-- orianna: ok -- hypothetical test fixture paths, not real files -->
2. **Trailer forgery is caught** — test: non-Orianna author + `Promoted-By: Orianna` trailer present -> hook REJECTS.
3. **Non-promotion commits cannot create plans in non-proposed stages** — test: a fresh create of `plans/approved/personal/bar.md` by a non-Orianna, non-admin author -> hook REJECTS. <!-- orianna: ok -- hypothetical test fixture path, not a real file -->
4. **Sweep script idempotence** — run T3's sweep twice; second run produces zero diff.
5. **Lifecycle smoke** — end-to-end: Orianna agent (invoked in a test harness) approves a proposed plan, the move + commit lands cleanly, pre-push hook passes.
6. **Admin-only protection of Orianna's agent def** — test: non-admin author modifying `.claude/agents/orianna.md` -> hook REJECTS. <!-- orianna: ok -- prospective path, created by this plan -->

All tests live in the scripts/hooks directory alongside existing `test-*.sh` files and are wired into `scripts/hooks/test-hooks.sh`.

## References

- `CLAUDE.md` Rule 19 (current regime to replace)
- `architecture/plan-lifecycle.md` (to be rewritten)
- `plans/implemented/2026-04-20-orianna-gated-plan-lifecycle.md` (origin of v2 regime — historical context only)
- `.claude/_script-only-agents/orianna.md` (current prompt, to be relocated and simplified)
- `scripts/_archive/v1-orianna-gate/` <!-- orianna: ok -- prospective archive path, created by this plan --> (destination for archived v1 scripts)
