---
status: proposed
concern: personal
owner: karma
created: 2026-04-24
tests_required: true
complexity: quick
orianna_gate_version: 2
tags: [identity, anonymity, hooks, reviewer-pipeline, work-scope]
related:
  - agents/evelynn/inbox/archive/2026-04/20260423-1450-955853.md
  - agents/sona/learnings/2026-04-23-w2-tdd-ordering-violation-viktor.md
  - scripts/hooks/_lib_reviewer_anonymity.sh
  - scripts/hooks/pre-commit-reviewer-anonymity.sh
  - scripts/reviewer-auth.sh
  - agents/evelynn/memory/open-threads.md
---

# Subagent identity-leak fix (commit author + reviewer footer)

## 1. Context

Two identity-leak classes surfaced on `missmp/company-os` PRs #91 and #96 post-merge. Both violate the spirit of CLAUDE.md Rule on "never include AI authoring references in commits" — the literal rule bans Anthropic/Claude co-author trailers, but the spirit covers any external disclosure of the strawberry agent system to MMP teammates who can view those PRs. <!-- orianna: ok -->

**Problem 1 — commit author leaks agent names.** Subagents inherit per-worktree `.git/config` `user.name` / `user.email` from whoever last committed in that worktree. External `git log` on work-repo merges shows authors like `viktor@strawberry.local` and `orianna@strawberry.local`. Reproduced this session: Swain commits under Orianna identity, Rakan xfail commits under Viktor identity. The existing `scripts/hooks/pre-commit-reviewer-anonymity.sh` only scans the commit message body — it does not scan the author line, so it cannot catch this. <!-- orianna: ok -->

**Problem 2 — reviewer verdict bodies leak agent names via the fallback pipeline.** `scripts/reviewer-auth.sh` already runs `anonymity_scan_text` on work-scope PR review bodies and rejects denylist hits. However, the reviewer-failure fallback documented in `agents/evelynn/CLAUDE.md` routes Senna/Lucian verdicts through `/tmp/<reviewer>-pr-N-verdict.md` → Yuumi `gh pr comment -F <file>` under `Duongntd`. That path does not touch `scripts/reviewer-auth.sh`, so `— Senna` / `— Lucian` footers post verbatim. Both PR #91 and #96 comments exhibit this. <!-- orianna: ok -->

Fix shape is structural on both problems. For P1, bind `user.name` / `user.email` (and matching `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env) to a generic work-scope identity via a new PreToolUse Bash hook that fires on every `git commit` attempt in a work-scope worktree — not a reminder, a guard. For P2, route the Yuumi fallback through a thin wrapper that runs the same `anonymity_scan_text` library and also strips trailing `— <AgentName>` signatures before posting, so the pipeline enforces the contract regardless of upstream drafting. <!-- orianna: ok -->

Scope guardrails: work-repo-specific installs (missmp pre-push, tdd-gate CI) are Sona's lane and are NOT in this plan. All changes here land under `~/Documents/Personal/strawberry-agents`; the enforcement runs when an agent operates on a work-scope worktree from this machine. <!-- orianna: ok -->

## 2. Decision

- **P1 (commit author):** Add a new PreToolUse Bash hook `scripts/hooks/pretooluse-work-scope-identity.sh`, wired via `.claude/settings.json`, that intercepts any Bash command containing `git commit` (or `git -c ... commit`) when the resolved cwd's git origin matches the work-scope regex (`[:/]missmp/`). The hook sets per-worktree `user.name="Duongntd"` and `user.email="103487096+Duongntd@users.noreply.github.com"` via `git -C <cwd> config --local` BEFORE the command runs. This is Duong's real hand-commit identity on work trees (verified against `~/Documents/Work/mmp/workspace` local config 2026-04-24) — external viewers cannot distinguish agent-driven from human-driven commits. This is fail-closed: if `git config` write fails the hook blocks the commit. <!-- orianna: ok -->
- **P1 enforcement at commit-msg layer too:** Extend `scripts/hooks/_lib_reviewer_anonymity.sh` with an `anonymity_scan_author` helper and call it from a new `commit-msg` or pre-commit hook branch that reads `git var GIT_AUTHOR_IDENT` and fails on denylist tokens in the author line. Defence in depth — the PreToolUse hook handles the happy path, the pre-commit/commit-msg guard catches anything that slipped (e.g. a scripted commit with `--author=` override).
- **P2 (reviewer footer):** Add `scripts/post-reviewer-comment.sh` as the ONLY sanctioned path for the Yuumi fallback. It takes `--pr N --repo <owner>/<repo> --file /tmp/<reviewer>-pr-N-verdict.md` and: <!-- orianna: ok -->
  1. Strips a trailing `— <Name>` / `-- <Name>` signature line (matched against the agent denylist) before posting.
  2. Runs the stripped body through `anonymity_scan_text`; rejects on any hit (exit 3), same contract as `scripts/reviewer-auth.sh`.
  3. Calls `gh pr comment N --repo <r> -F <stripped-file>` under the caller's default identity (Duongntd is fine — the content is now clean).
- **Template alignment:** Update Senna and Lucian agent defs so the canonical verdict template ends with a neutral role tag (`-- reviewer`) rather than `— Senna` / `— Lucian` on work-scope PRs. This removes the signature at the source and makes the stripper a belt-and-braces layer.
- **Evelynn CLAUDE.md fallback section:** Update step 3 of "Reviewer-failure fallback" to mandate `scripts/post-reviewer-comment.sh` and forbid raw `gh pr comment -F`. <!-- orianna: ok -->

Why quick lane: single domain (agent-infra hooks + reviewer pipeline), no schema, no new external integrations, ~5 tasks, ≤ 120 AI-minutes. Two fixes share one library (`scripts/hooks/_lib_reviewer_anonymity.sh`) so the blast radius stays contained.

## 3. Non-goals

- No changes to `missmp/company-os` or any other work-repo file. The tdd-gate CI and work-repo pre-push install are Sona's separate plan. <!-- orianna: ok -->
- No new `Co-Authored-By` trailers; none are being added — `scripts/hooks/commit-msg-no-ai-coauthor.sh` already exists.
- No attempt to rewrite history on PRs #91 / #96 — those are merged and external viewers have already seen them. This plan prevents future leaks only.
- No change to `scripts/reviewer-auth.sh` call sites — Senna/Lucian continue to submit reviews through it; only the fallback-comment path is new.

## 4. Tasks

### T1. PreToolUse work-scope identity hook
- kind: script
- estimate_minutes: 25
- files: `scripts/hooks/pretooluse-work-scope-identity.sh` (new), `.claude/settings.json`. <!-- orianna: ok -->
- detail: Read tool_input JSON from stdin. When tool is Bash and command contains `git commit`, resolve the effective cwd (fall back to `$PWD`), check `git -C <cwd> remote get-url origin` against `[:/]missmp/`. If work-scope, run `git -C <cwd> config --local user.name "Duongntd"` and `user.email "103487096+Duongntd@users.noreply.github.com"`. On any failure, emit block JSON and exit 2. On non-work-scope or non-commit commands, exit 0 silently. Wire into `.claude/settings.json` under the existing `PreToolUse.Bash` list, after `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`. POSIX-portable bash per Rule 10. <!-- orianna: ok -->
- DoD: hook file exists, is executable, is listed in settings.json, and a dry-run invocation with a synthetic `git commit` tool_input payload against a work-scope worktree sets the config; against a non-work-scope repo leaves config untouched.

### T2. Author-scan extension to the anonymity library
- kind: script
- estimate_minutes: 20
- files: `scripts/hooks/_lib_reviewer_anonymity.sh`, `scripts/hooks/pre-commit-reviewer-anonymity.sh`.
- detail: Add `anonymity_scan_author` that reads `git var GIT_AUTHOR_IDENT` (or accepts stdin for tests) and runs the same denylist scan against `Name <email>` form. Call it from `scripts/hooks/pre-commit-reviewer-anonymity.sh` alongside the existing commit-message scan when `anonymity_is_work_scope` returns true. Fail with a specific message identifying the leaked token. <!-- orianna: ok -->
- DoD: running `scripts/hooks/pre-commit-reviewer-anonymity.sh` in a work-scope worktree with `user.name=Viktor` fails with a clear message; running with `user.name=Duongntd` passes.

### T3. Reviewer-comment wrapper for the Yuumi fallback
- kind: script
- estimate_minutes: 25
- files: `scripts/post-reviewer-comment.sh` (new). <!-- orianna: ok -->
- detail: Flags `--pr <N>`, `--repo <owner>/<repo>`, `--file <path>`. Reads file, strips trailing signature matching `^(—|--) *(Senna|Lucian|Evelynn|Sona|Viktor|Jayce|Azir|Swain|Orianna|Karma|Talon|Ekko|Heimerdinger|Syndra|Akali)\s*$` (source from `scripts/hooks/_lib_reviewer_anonymity.sh` token table — single source of truth). Writes stripped body to a temp file, runs `anonymity_scan_text` from the shared library; on hit, prints rejection to stderr and exits 3 (same contract as `scripts/reviewer-auth.sh`). On pass, exec `gh pr comment <N> --repo <r> -F <tmpfile>`. Fail-closed on missing file / no PR / scan hit.
- DoD: script exists, executable; a fixture file ending `-- Senna` posts successfully with the footer stripped; a fixture containing `Evelynn` inline exits 3 and posts nothing.

### T4. Verdict template updates for work-scope reviews
- kind: doc-edit
- estimate_minutes: 10
- files: `.claude/agents/senna.md`, `.claude/agents/lucian.md`.
- detail: Update the "Work-scope Anonymity" sections to mandate `-- reviewer` (neutral) as the signature on work-scope PRs, replacing any `— Senna` / `— Lucian` guidance. Personal-concern PRs keep the persona signature (they are not externally visible to MMP teammates).
- DoD: both agent defs say `-- reviewer` explicitly for work-scope; no remaining instruction to use the persona name in work-scope review bodies.

### T5. Evelynn fallback section update
- kind: doc-edit
- estimate_minutes: 10
- files: `agents/evelynn/CLAUDE.md`.
- detail: In "Reviewer-failure fallback", change step 3 to: `Yuumi picks up the file and posts via scripts/post-reviewer-comment.sh --pr N --repo <r> --file <path>. Never raw gh pr comment -F on work-scope PRs.` Add a one-line note that the wrapper strips reviewer-name footers and runs the anonymity scan.
- DoD: the fallback section names `scripts/post-reviewer-comment.sh` and forbids raw `gh pr comment` on work-scope. <!-- orianna: ok -->

### T6. Wire Agent-tool harness env for the common case
- kind: script
- estimate_minutes: 20
- files: `scripts/hooks/agent-default-isolation.sh`, or a new sibling `scripts/hooks/agent-identity-default.sh` (new). <!-- orianna: ok -->
- detail: When the Agent tool dispatches a subagent and the resolved workdir is work-scope, inject `env: {GIT_AUTHOR_NAME: "Duongntd", GIT_AUTHOR_EMAIL: "103487096+Duongntd@users.noreply.github.com", GIT_COMMITTER_NAME: "Duongntd", GIT_COMMITTER_EMAIL: "103487096+Duongntd@users.noreply.github.com"}` into the dispatch payload. This layer catches any commit path that bypasses the per-worktree config (e.g. fresh clone inside the subagent). Non-work-scope dispatches are untouched. POSIX-portable.
- DoD: dry-run Agent dispatch against a work-scope `cwd` shows the four GIT_* vars present in the modified tool_input; personal-scope dispatch shows them absent.

## Test plan

Tests live under `scripts/hooks/tests/` alongside existing hook tests. Language: bash, using the same style as `scripts/hooks/test-pre-commit-reviewer-anonymity.sh`. <!-- orianna: ok -->

Invariants the tests protect:

- **INV-1 (commit author anonymity on work-scope):** A commit attempted from a work-scope worktree with a persona identity in `.git/config` must either be auto-rewritten to the neutral identity (T1 happy path) OR fail to commit (T2 defence-in-depth). Test both: (a) work-scope repo, persona config pre-set, run PreToolUse hook → config becomes neutral, commit proceeds; (b) work-scope repo, somehow persona slipped past (simulate by skipping T1), run pre-commit hook → blocks with denylist message; (c) personal-scope repo, persona config → untouched, commit proceeds.
- **INV-2 (reviewer-comment wrapper scrubs + scans):** `scripts/post-reviewer-comment.sh` must strip trailing agent-name signatures AND reject any body with inline denylist tokens on work-scope PRs. Test fixtures: (a) body ending `-- Senna` → stripped, posted; (b) body containing `Orianna reviewed...` inline → exit 3, no post; (c) clean body → passes through unchanged. <!-- orianna: ok -->
- **INV-3 (personal-scope untouched):** Nothing in this plan alters commit authorship, comment bodies, or review bodies on personal-concern PRs. Test: run each new hook / script against a personal-scope fixture repo and assert zero mutation.
- **INV-4 (agent-tool harness env injection):** T6 must inject `GIT_AUTHOR_NAME/EMAIL` only when the target `cwd` resolves to a work-scope origin. Unit-test the env-construction function with both scope fixtures.

xfail-first discipline (Rule 12): each implementation commit must be preceded on the same branch by an xfail test commit citing this plan's task ID. TDD gate blocks otherwise.

## 6. Rollout

1. Land as a single PR under this plan. Senna + Lucian dual review per Rule 18.
2. After merge, Evelynn announces via agent-network.md note: "work-scope commit author + reviewer footer are now structurally enforced; see `plans/implemented/personal/2026-04-24-subagent-identity-leak-fix.md`."
3. Sona picks up the separate work-repo-specific tdd-gate install plan — cross-reference from there.

## 7. Open questions

- ~~Should the neutral identity be `strawberry-agent` or something more bot-like?~~ **RESOLVED 2026-04-24:** Duong directed "work should not concern me about agents and identity — use mine." Identity is `Duongntd <103487096+Duongntd@users.noreply.github.com>`, matching his real hand-commit identity on `~/Documents/Work/mmp/workspace` (verified). Commits on missmp work-scope become indistinguishable from human commits — zero orchestration signal.
- T6 depends on the Agent-tool harness respecting an `env` key in dispatch payloads. If Claude Code does not pass arbitrary env through to the subagent process, T6 downgrades to documentation + relies solely on T1+T2. Mark as must-verify during T6 spike; fallback path is T1+T2-only and still closes both problems.

## 8. References

- Incident write-up: `agents/evelynn/inbox/archive/2026-04/20260423-1450-955853.md`.
- Sona TDD-ordering learning (patterns 3–4): `agents/sona/learnings/2026-04-23-w2-tdd-ordering-violation-viktor.md`.
- Existing work-scope anonymity infra: `scripts/hooks/_lib_reviewer_anonymity.sh`, `scripts/hooks/pre-commit-reviewer-anonymity.sh`, `scripts/reviewer-auth.sh`.
- CLAUDE.md Rule on AI authoring references (spirit extension).
- Open-threads entry: `agents/evelynn/memory/open-threads.md` section "Identity leaks on work-repo PRs (Evelynn-owned fix)".
