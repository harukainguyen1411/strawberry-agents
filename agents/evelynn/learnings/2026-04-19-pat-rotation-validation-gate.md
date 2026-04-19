# 2026-04-19 — PAT rotation needs a validation gate

## What happened

Duong minted a fresh `Duongntd` classic PAT and dropped it in `secrets/`. I pointed Ekko at the wrong file (`secrets/github-triage-pat.txt` — stale from S49) instead of the actual fresh one (`secrets/github_pat.txt` — 40 bytes, newer mtime). Ekko dutifully encrypted, set `AGENT_GITHUB_TOKEN`, shredded the plaintext, and reran `Auto-rebase PR`. Still 401.

We burned a whole back-and-forth cycle ("token is stale, mint a new one") before Duong's one-character reply (`1`) clarified that the right file was the other one. Memory bias — I remembered the S49 filename (`github-triage-pat.txt`) and assumed Duong used the same one.

## The fix that should be standard

Before encrypting OR setting a GH secret:

```sh
GH_TOKEN="$(cat secrets/<file>)" gh api user --jq .login
```

Must print the expected account name (`Duongntd` for agent ops). If it doesn't, stop — the file is either stale, revoked, or was minted from the wrong account. Do not write the secret.

This is 2 seconds of API call. It would have collapsed an entire round-trip into one cycle.

## Companion rule — file identification

When Duong says "the token is in secrets" or any similar "the X is at Y," don't trust the filename from memory. Run:

```sh
ls -lt secrets/*.txt
```

Grab the one with the newest mtime. Filenames are sticky across sessions; mtimes aren't.

## Where it applies

- PAT rotation (this case)
- Discord webhook rotation
- Any encrypted-blob workflow where plaintext lives briefly in `secrets/` before shredding
- Any case where the fresh value arrives via a user-written file and the ask is "encrypt + set + commit"

## Related

- S49 learning `2026-04-18-identity-audit-gap.md` — same family (identity infrastructure goes unaudited). That one was about gh auth + git config; this one is about token validity. Both need startup/rotation hooks.
- CLAUDE.md Rule 6 (never raw `age -d`) and Rule 2 (secrets not in committed files) — orthogonal to this; those prevent leakage. Validation gate prevents wasted cycles on silently-wrong values.
