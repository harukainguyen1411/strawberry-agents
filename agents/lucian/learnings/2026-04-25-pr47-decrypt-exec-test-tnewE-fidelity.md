# PR #47 — T-new-E decrypt-exec integration test fidelity (2026-04-25)

**Repo:** harukainguyen1411/strawberry-agents
**PR:** #47 `feat/decrypt-exec-test` — Syndra
**Plan:** plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md T-new-E
**Verdict:** APPROVE
**Review:** https://github.com/harukainguyen1411/strawberry-agents/pull/47#pullrequestreview-4174991619

## Pattern: positive-integration-test fidelity reviews

T-new-E was a "regression probe against existing impl" — not a TDD-style xfail-first task. Rule 12 doesn't apply because no new code-under-test is introduced; the test guards an already-shipped surface (`tools/decrypt.sh --exec`). Same logic for Rule 13 (not a bug fix). Document this carve-out: positive integration tests for ratified surfaces are exempt from xfail-first.

## Pattern: §4.2 canonical-pattern alignment check

When the parent ADR has been recently rewritten (here: 18f90d7e by Aphelios replaced the wrong stdout-capture template with the `--exec`-based canonical), the fidelity check collapses to: grep the test's actual decrypt.sh invocation and confirm it matches the four §4.2 hallmarks — (1) ciphertext on stdin via `<` or pipe, (2) `--target` under `secrets/work/runtime/`, (3) `--var <NAME>`, (4) `--exec --` replacing the shell. Any `TOKEN="$(decrypt.sh …)"` shape would be a structural block (resurrects the wrong template). PR #47 matched all four.

## Pattern: hook auto-discovery via dispatcher glob

`scripts/install-hooks.sh` runs every `scripts/hooks/pre-commit-*.sh` alphabetically — so adding a new hook file requires no install-hooks edit. T-new-E's pre-commit gate is wired purely by virtue of file naming. Useful to know for future "wired into the pre-commit lane" DoD checks.

## Pattern: Rule 6 vs `age-keygen -y`

Rule 6 prohibits raw `age -d` and reading plaintext key material. `age-keygen -y <key-file>` extracts the PUBLIC key only and is sanctioned. `age -r <pub> -a` (encrypt-only with recipient) is also sanctioned. Tests that need a fixture ciphertext at runtime (no committed `.age` blob, no throwaway keypair) can use this pattern: `pub=$(age-keygen -y secrets/age-key.txt); ct=$(printf '…' | age -r "$pub" -a); printf '%s' "$ct" | tools/decrypt.sh …`. Decryption still goes exclusively through `tools/decrypt.sh`.

## Drift catalogue

- D-1: tautological "absence in parent shell" assertion — pre-seed parent var to make it meaningful.
- D-3: `secrets/work/runtime/` lacks an explicit gitignore stanza; relies on top-level `secrets/` ignore.
- D-4: commit author attribution drift (Orianna vs PR author Syndra).

These are advisory; PR is approved.
