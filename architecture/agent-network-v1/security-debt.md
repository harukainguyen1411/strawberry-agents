# Security Debt

Known gaps in the Strawberry security posture, deferred but tracked.

## Windows host hardening (deferred — 2026-04-08)

The Windows account `LAPTOP-M2G924A5\AD` that runs Claude Code and holds `secrets/age-key.txt` has not been audited for: admin vs standard-user posture, BitLocker status on `C:`, OS-account password strength, sleep/lock timeout, or remote-access surface (RDP/SSH/etc.). Pyke flagged this in the encrypted-secrets review (Open Question 5). The encrypted-secrets system reduces *exposure surface* but not *post-compromise blast radius* — if the Windows box is owned, the age private key is exposed and every secret ever encrypted to it (including in git history) is plaintext to the attacker. Mitigations to address in a follow-up: enable BitLocker on `C:`, run the agent under a standard (non-admin) user where possible, set a short auto-lock, and document the recovery procedure for losing the key. Until then, treat the Windows box as a single point of failure for everything in `secrets/encrypted/`.
