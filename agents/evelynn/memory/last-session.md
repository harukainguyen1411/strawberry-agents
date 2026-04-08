# Last Session — 2026-04-08 (Direct mode, cafe session, Windows side)

**Mode:** Direct, all day. Duong on his Mac at a cafe via Claude Desktop Remote Control to Windows Claude Code. Long session.

## Critical for next session — read first

1. **RESTART this session before doing anything else.** `.claude/agents/poppy.md` was created mid-session and the harness only loads subagents at startup. Without restart, Poppy is NOT invokable as `subagent_type: poppy`.
2. **Yuumi may or may not still be alive.** She was launched as a separate Claude Code process (PID 3312, command line `--remote-control "Yuumi"`) at session end via detached `Start-Process`. First restart will tell whether she survived. If she's gone, relaunch via `windows-mode\launch-yuumi.bat`.
3. **30 plans are currently mirrored in Drive but should NOT be.** They will be unpublished as part of the migration in Swain's revision plan (item 1 in open threads). Do not publish more in the meantime.

## What shipped (all committed + pushed to origin/main)

- **Encrypted-secrets system** end-to-end live. Cafe protocol: encrypt on Mac with `tools/encrypt.html` (or age CLI to `age16zn6u722syny7sywep0x4pjlqudfm6w70w492wmqa69zw2mqwujsqnxvwm`), paste ciphertext via chat OR commit `.age` blob to `secrets/encrypted/` and push, agent runs `tools/decrypt.sh --target secrets/<group>.env --var <KEY> < <blob>`. Plaintext never crosses chat or transcript folder.
- **Plan-gdoc-mirror** end-to-end live. Google OAuth credentials delivered via encrypted blobs (Duong pushed `.age` files, Evelynn pulled+decrypted). Drive folder ID is non-secret, written directly: `1ygXvAK2mP-JnCs5Mq3jiszho64MuKrdU`. 30 plans bulk-published.
- **Poppy** Haiku mechanical-edits minion built. `agents/poppy/` + `.claude/agents/poppy.md` (tracked). Invokable after restart.
- **Yuumi** as separate Claude Code instance (NOT subagent). Launcher: `windows-mode\launch-yuumi.bat` with `--dangerously-skip-permissions`. Restart script: `scripts/restart-evelynn.ps1` — discovery filter verified, kill+launch path UNTESTED live.
- Mac↔Windows git divergence resolved (merge commit `dd05a74`).
- Frontmatter fix on 2 byte-corrupted plan files; `plan-publish.sh` hardened to fail on `frontmatter_set` no-op.
- Bard's research clarified Remote Control = native Claude Desktop product, NOT MCP. Transport NOT E2E. Anthropic relay retention: 30d default, 5y if model-improvement on. Local Windows transcripts at `~/.claude/projects/` retain 30d plaintext.

## Open threads (priority order)

1. **Approve Swain's `plans/proposed/2026-04-08-gdoc-mirror-revision.md`** → executor runs migration: `plan-unpublish.sh` x30, delete 2 orphan gdocs (`1jZfFq1hf741g1B69CVYy6HFjo_Ly6Is3g0Gh7CR68Uo`, `1KHrc2XC368LBUXhLgd0q5QcP78pdqmx5cS1SKDB6dHs`), patch `plan-publish.sh` to refuse non-proposed targets, build `plan-promote.sh` wrapper. Decision: Drive = proposed-only (Option A).
2. **First live test of Yuumi's restart command.** Say "restart Evelynn" to Yuumi in Claude Desktop. Watch for clean kill+relaunch. Fallback: manual `launch-evelynn.bat` from Explorer.
3. **Wire remaining roster as actual harness subagents** — Ornn, Fiora, Shen, Caitlyn exist in `roster.md` but NOT in `.claude/agents/`. The .md roster is mostly aspirational. Needs a Syndra systematic-wiring plan.
4. **Pyke's cafe-from-home plan** is mostly moot now (Remote Control already supports cafe usage natively). Needs Pyke scope-down pass to focus on edges only (file transfer, restart wrapper).
5. **Zilean still not launched.** Worth meeting him before proposing Galio (ops/service wrangler) — they may overlap.

## Pending Galio decision

Duong did not approve or reject the Galio (service/operations wrangler) proposal. Pending his judgment in a future session.

## Lessons saved

- `~/.claude/projects/.../memory/feedback_no_parallel_clones.md` (user memory) — never parallel clones; use distinct specialists; my real Sonnet pool is katarina + general-purpose (1 each)
- `agents/evelynn/learnings/2026-04-08-roster-vs-harness-reality.md` — the roster is theater; harness reality is ~6 subagents

## Ended cleanly

Yuumi running (PID 3312 at end), no in-flight agents, working tree clean, all commits pushed (`origin/main`).
