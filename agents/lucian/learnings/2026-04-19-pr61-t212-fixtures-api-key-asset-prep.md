# PR 61 — T212 API fixtures + encrypted key (asset-prep for optional v1 adapter)

**Repo:** harukainguyen1411/strawberry-app
**Verdict:** APPROVE (default lane → strawberry-reviewers)
**Review ID:** PRR_kwDOSGFddc72iF9R

## What it was

Pure asset-prep PR: 3 anonymized JSON fixtures for T212 REST API responses
(cash, portfolio, orders) + `secrets/env/T212.env.age` (age-encrypted API key).
No implementation code. `chore:` prefix.

## Why it passes fidelity despite T212 API being "optional v1+"

ADR (Azir 2026-04-19 revision) explicitly demoted T212 REST adapter to optional
v1+ enhancement — it's *not removed from the roadmap*. Landing anonymized
fixtures + encrypted credentials now is prep-work; it introduces zero
implementation, handlers, or adapter code. No scope creep, since scope creep
would be *code* not *data*.

## Rule 6 reading

Rule 6 forbids raw `age -d` and reading plaintext into context. Committing a
`.age` ciphertext is the *standard storage* pattern, not a violation. The
`.gitignore` pattern `secrets/env/*` + `!secrets/env/*.age` correctly
whitelists only ciphertext. Confirmed the strawberry-app `.gitignore` has this.

## Pattern to remember

For asset/fixture-only PRs:
- No xfail test needed (xfail-first check no-ops on asset-only diffs and passes).
- No regression test needed.
- `chore:` is correct prefix for `apps/**` asset paths when no behavior changes.
- Check anonymization scope: IDs, cursors, tokens redacted; market data OK to
  keep since it's public.
