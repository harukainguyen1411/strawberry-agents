# Ekko Memory

## Persistent Context

- Working tree shared — always `git add <specific-files>`, never `git add -A` or `git add .`
- `scripts/safe-checkout.sh` for branches — never raw `git checkout`
- `tools/decrypt.sh` for decryption — never raw `age -d`
- `scripts/reviewer-auth.sh` MUST be run from strawberry-agents dir — decrypt.sh refuses targets outside its secrets/
- `scripts/reviewer-auth.sh` — wraps `gh` with strawberry-reviewers identity. Run from strawberry-agents dir.
- `harukainguyen1411/strawberry-app` cloned at `~/Documents/Personal/strawberry-app`
- Required checks for main: xfail-first, regression-test, unit-tests, Playwright E2E, QA report. `E2E tests (Playwright / Chromium)` is NOT required — pre-existing auth-local-mode heading bug.
- No classic branch protection on strawberry-app (404). No rulesets. CLEAN/MERGEABLE is sufficient to merge.
- `tools/decrypt.sh`: reads ciphertext stdin, writes `KEY=val` to `--target` (must be under `secrets/`). Use `cat secret.age | tools/decrypt.sh --target secrets/x.env --var KEY --exec -- cmd`.

## Sessions

- 2026-04-19 (ekko s23): PR #57 V0.7 IB CSV — merged origin/main, 4 conflicts resolved, TDD-Waiver added. All 14 CI checks green.
- 2026-04-19 (ekko s24): PR #45 V0.11 CSV Import Step 1 — merged origin/main, 5 conflicts resolved. Pushed b985c68.
- 2026-04-19 (ekko s25): merged PR #42 (V0.8 importCsv handler) via reviewer-auth.sh. Merge SHA: 73b9e2a.
- 2026-04-19 (ekko s26): merged PR #58 (fix/main-red-portfolio-cascade-residue) — merged origin/main, no conflicts, all CI green, squash-merged. Merge SHA: adbfe57.
- 2026-04-19 (ekko s27): promoted 2 plans (stale-green-merge-gap, reviewer-identity-split) to approved via plan-promote.sh; fixed stale proposed/-path ref that Orianna gate correctly blocked.
- 2026-04-19 (ekko s28): merged PR #45 (V0.11 CSV Import Step 1) via reviewer-auth.sh. Merge SHA: 5d026ef. Branch deleted.
- 2026-04-19 (ekko s29): added `--lane <name>` to reviewer-auth.sh (Phase 3 reviewer-identity-split). Commit 306fed2. Default lane unchanged.
- 2026-04-19 (ekko s30): encrypted senna PAT → reviewer-github-token-senna.age; round-trip verified strawberry-reviewers-2; shredded plaintext. Commit 95064e1.
- 2026-04-19 (ekko s31): Phase 4 dry-run — PR #3 on strawberry-agents; Senna→strawberry-reviewers-2, Lucian→strawberry-reviewers; two distinct approvals confirmed; PR closed, branch deleted.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
