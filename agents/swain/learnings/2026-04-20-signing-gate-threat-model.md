# Signing-gate threat model in solo-operator agent systems

When designing a gate where one agent signs off on another's work, the tempting
move is to reach for cryptographic signatures (GPG, detached sig files, hash
ledgers). That's the wrong instinct in a solo-dev system like Strawberry.

**The real attacker vector is not malice — it's omission.**

The failure mode is "an agent forgot to invoke the gatekeeper before moving
the artifact forward," not "a malicious committer forged the gatekeeper's
signature." The gate needs to be *presence-verified*, not
*cryptographically unforgeable*.

## Cheapest mechanism that works

1. **Per-agent git author identity.** Give the gatekeeper a distinct
   `author@agents.local` email. Downstream gates read the commit that
   introduced the signature and verify authorship.
2. **Body-hash in the signature field.** Catches "sign, then edit" —
   signer's content-hash must match the current body at verify time.
3. **Diff-scope check on signing commits.** A pre-commit hook enforces that
   commits authored by the gatekeeper touch only the artifact being signed
   and add only the signature line. Without this, an agent can bundle
   unrelated changes into a signing commit.

Three lightweight checks. No key management, no second filesystem location,
no rotation burden.

## Where the ceremony actually belongs

Ceremony earns its keep only at human-adversarial boundaries:

- PRs crossing from agent account to main (branch protection).
- Bypass trailers (`Orianna-Bypass:`) — restrict to Duong's personal
  identity, not the agent account.
- Break-glass merges.

Inside the agent plane, author-email + body-hash + diff-scope is enough.

## The reject-by-inference trap

Adjacent pattern: when designing the architecture-freshness check (§D5 of
the 2026-04-20 ADR), I had to resist writing a heuristic to *infer* whether
a plan touched architecture-relevant components. Heuristics on subjective
categories ("does this plan need an architecture update?") are wrong half
the time. Force the author to commit to one of two options — a list of
files changed, or an explicit `impact: none` with a one-line reason. Shift
the decision to where the knowledge is.

This generalizes: any check that would require the gatekeeper to *guess
intent* should instead demand an explicit declaration from the author and
verify the declaration.
