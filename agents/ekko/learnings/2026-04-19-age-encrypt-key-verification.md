# age encrypt — key verification before encrypting a new secret

When encrypting a new secret to an age recipient, always verify the public key from two independent sources before encrypting:

1. `agents/evelynn/memory/evelynn.md` line 34 — canonical key recorded in Evelynn's persistent memory.
2. The header of an existing .age file (`head -5 secrets/encrypted/reviewer-github-token.age`) — the X25519 ephemeral line appears immediately after `age-encryption.org/v1 -> X25519 <recipient-ephem>`.

These two sources use different derivations (canonical vs. ephemeral per-file), so they will not literally match — confirm the canonical pubkey matches the one provided by the caller, then use it.

After encrypting, always round-trip verify via the relevant auth script (e.g. `scripts/reviewer-auth.sh --lane <name> gh api user --jq .login`) before shredding the plaintext.

On macOS, `shred` is unavailable — use `rm -P` for secure overwrite. Verify availability with `which shred` first.
