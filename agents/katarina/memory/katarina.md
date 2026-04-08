# Katarina

## Role
- Fullstack Engineer — Quick Tasks

## Sessions
- 2026-04-03 (S1): Verified HTML tasklist UI, ported 4 features to Vue migration (myapps PR #53), fixed touch drag regression.
- 2026-04-03 (S2): Built contributor pipeline Discord bot (`apps/contributor-bot/`), applied Swain's review fixes.
- 2026-04-03 (S3): Set up GitHub webhook for Discord #pr-and-issues notifications.
- 2026-04-04 (S4): Built `apps/discord-relay/` bot + `scripts/discord-bridge.sh` + `scripts/result-watcher.sh` for Discord-CLI integration.
- 2026-04-05 (S5): Diagnosed + fixed GH_TOKEN shell scoping bug and per-agent API key isolation in `mcps/agent-manager/server.py`. PRs #29 and #30.
- 2026-04-05 (S6): Executed team-plan migration — removed API key injection from server.py, cleaned all agent settings.local.json, updated billing docs. PR #31.
- 2026-04-05 (S7): Heartbeat fix (PR #32) + restart safeguards (PR #34). Restarted Evelynn twice.
- 2026-04-08 (S8, subagent): Mechanical plan-file maintenance — recorded blanket-approval Decisions on skills-integration, minion-layer, rules-restructure (Q2/Q6 PENDING); promoted skills-integration, minion-layer, plan-gdoc-mirror to approved/; archived Tibbers errand-runner plan with supersession note. Commit 6879747.
- 2026-04-08 (S9, subagent): Resolved rules-restructure Q2/Q6 (Q2 = Evelynn's call, place rule in delegation cluster; Q6 = leave secrets feedback as-is); promoted rules-restructure to approved/; swept all 6 archived plans to status: archived.
- 2026-04-08 (S10, subagent): Implemented plan-gdoc-mirror — 4 bash scripts (publish/fetch/unpublish/oauth-bootstrap), `_lib_gdoc.sh`, offline tests (11 passing), `architecture/plan-gdoc-mirror.md`. Wraps frontmatter in `yaml plan-frontmatter` fenced block for round-trip survival. Credentials sourced from gitignored `secrets/google-*.env` files (one per key) populated by sibling's `tools/decrypt.sh`. End-to-end Drive verification deferred until OAuth credentials provisioned. Plan promoted to implemented/. Commits 3cac098 + 36e2ca3.
- 2026-04-08 (S12, Caitlyn stand-in, subagent): Bulk-published 30/32 plans to Drive via `scripts/plan-publish.sh`. 2 failures: `2026-04-04-git-safety-shared-workdir.md` and `2026-04-04-pr-documentation-rules.md` — both have a stray leading char (`l`/`i`) before `---` on line 1, causing `gdoc::frontmatter_set` to silently no-op. Gdocs were created in Drive (orphans) but no link committed. Pushed 31 commits (30 publish + Poppy's encrypted-blob delete) as 353275a..6480556. Not Katarina-flavored work, but clean execution.
- 2026-04-08 (S13, subagent): Three-task cleanup batch. (1) Stripped leading junk byte from the two malformed plan files from S12 — commit 511932a. (2) Patched `scripts/plan-publish.sh` to grep-verify gdoc_id/gdoc_url landed in the markdown after `gdoc::frontmatter_set`, hard-failing with a cleanup message if not; smoke-tested end-to-end against a malformed fixture (Drive doc created → local write no-op → exit 1). Orphan smoke-test doc hard-deleted via Drive API. Commit 3e0eafe. (3) Decision: `.claude/agents/` is tracked (6 sibling definitions already in git, `.gitignore` has no rule, windows-mode/README.md implicitly assumes repo-tracked) — added `.claude/agents/poppy.md`, commit 007e153. Pushed batch 85e84a5..007e153 (included Swain's da85c21 gdoc-mirror-revision plan).
- 2026-04-08 (S11, subagent): Implemented encrypted-secrets ship-now (plan 2026-04-08-encrypted-secrets). Installed age v1.2.0 to /c/Users/AD/bin, generated `secrets/age-key.txt` with locked icacls (only LAPTOP-M2G924A5\AD), derived recipient pubkey, built `tools/decrypt.sh` (stdin-only, atomic write, `exec env` form, refuses targets outside secrets/), bundled `age-encryption@0.2.4` JS via esbuild into `tools/age-bundle.js` (73KB IIFE), built `tools/encrypt.html` with baked recipient + SHA256 sidecar, wrote `scripts/pre-commit-secrets-guard.sh` (4 guards: BEGIN AGE outside encrypted/, raw `age -d` outside helper, bearer-token shapes, decrypt-and-scan staged files for known plaintext values), installed `.git/hooks/pre-commit` shim, updated `.gitleaks.toml` allowlist, set `core.autocrlf false`, added CLAUDE rule 11, wrote `architecture/security-debt.md`, end-to-end test passed (encrypt a dummy literal → decrypt.sh → secrets/test.env → source verified → wiped → 0 git history matches; scrubbed the dummy literal out of this memory file in the follow-up commit). Plan promoted to implemented/. **Known issue:** S10's `scripts/_lib_gdoc.sh` (committed in 3cac098) contains raw `age -d` and will trip Guard 2 on next re-stage; needs cleanup commit to route through `tools/decrypt.sh` instead.

## Known Repos
- strawberry: Personal agent system (this repo)
- myapps (github.com/Duongntd/myapps): Personal apps — Vue 3 + Vite + Firebase + Tailwind. Strict pre-commit hooks (typecheck + tests + lint).

## Working Notes
- myapps pre-commit runs vue-tsc --noEmit — unused vars will block commits
- CLAUDE.md: no rebase, always merge; PRs with significant changes must update relevant README.md
- All commits use `chore:` or `ops:` prefix (enforced by pre-push hook on main)
- contributor-bot uses ESM (type: module), discord.js 14, @google/generative-ai, @octokit/rest
- Gemini model for triage: gemini-2.5-flash-lite-preview-06-17 (versioned ID required)
- discord-relay: ESM, discord.js 14, express only. File-based IPC via JSON in /home/runner/data/
- agent-manager server.py uses `$(cat file)` pattern to inject secrets without scrollback exposure
- Per-agent ANTHROPIC_API_KEY is gone — agents now auth via team plan login
- harukainguyen1411 now has write access to Duongntd/strawberry (token in secrets/agent-github-token)
