# 2026-04-23 — orianna-gate-simplification proposed→approved promotion

## Summary

Two-hop sign + promote for `2026-04-22-orianna-gate-simplification.md`.

## Key findings

### orianna-sign.sh vs plan-promote.sh use different checkers

`orianna-sign.sh` (Orianna agent fact-check) and `plan-promote.sh` (pre-commit-zz-plan-structure.sh)
extract and validate backtick path tokens differently. A plan can pass the sign step and then fail at
the promote step's lib-plan-structure check.

Specifically:
- `orianna-sign.sh` checks the plan file directly at its current path (proposed/)
- `plan-promote.sh` stages a `git mv` first, then runs the pre-commit hook on the renamed file — ALL
  lines are staged (new file creation), so every backtick token is checked

### lib-plan-structure blocks that orianna-sign.sh does NOT catch

1. **Bare script names** (no path prefix) in prose — `orianna-memory-audit.sh`, `git-identity.sh`,
   `_orianna_identity.txt`, `README.md`, etc. need `<!-- orianna: ok -->` or full `scripts/` prefix.
2. **Git config key tokens** — `user.email`, `user.name` in backticks look like path tokens to the
   lib-plan-structure checker. Add suppressor to the line.
3. **Backtick-enclosed existing directories** — `scripts/hooks/` or even `scripts/hooks` (no slash)
   causes `awk getline` to crash with "i/o error" on macOS because awk tries to read the directory as
   a file. Fix: remove backticks from the directory reference or rewrite prose without backtick on dir.
4. **Grep command fragments** — `` `grep -rl "..." plans/` `` — the `plans/` inside is picked up as
   a token, causing the same awk crash. Fix: rewrite prose to not use backticks around shell commands.

### Suppressor rule reminder

- Each suppressor on a line protects ALL backtick tokens on that line
- Suppressor must have a reason suffix: `<!-- orianna: ok -- reason here -->`
- The body-hash changes every time you add a suppressor, so the signature must be removed first,
  body fix committed, then re-signed

### Plan body hash cycle when lib-plan-structure blocks

1. `git restore --staged .` (clean staging before each sign attempt)
2. Remove stale `orianna_signature_approved:` line from frontmatter
3. Fix all blocks + commit the body-fix commit (specific file only)
4. Re-run `orianna-sign.sh` — Orianna re-checks + writes new signature
5. Run `plan-promote.sh`

## Commits

- Body fix (plans/** glob): `40896ab`
- Sign (first attempt — passed): `a48f51b` — then promote blocked by lib-plan-structure
- Body fix (lib-plan-structure blocks): `b50e3c0`
- Sign (second attempt — passed): `93071b7`
- Promote commit: `8b5f361` (pushed)

## Final path

`plans/approved/personal/2026-04-22-orianna-gate-simplification.md`
