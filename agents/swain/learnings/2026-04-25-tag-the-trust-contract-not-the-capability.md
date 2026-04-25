# Tag the trust contract, not the capability

When the failure mode is "agent X says A about source code but the claim is unverified inference" — the structural lever is the **report contract**, not the **agent's tool surface**.

Original instinct (drafted under Sona's first-pass framing): remove `Read`/`Grep`/`Glob` from Akali's tools. Make confabulation mechanically impossible by removing the capability. "Once she cannot Read, she cannot guess."

Sona's mid-flight correction (after she discovered her PR #32 verification ran on the wrong worktree HEAD, and Akali's findings were actually accurate): **a capability ban is too sharp**. It throws away Akali's verified-tagged findings (which work fine) along with her inferred-tagged findings (which are the actual problem). The right fix is per-finding **citation tagging**: `cite_kind: verified | inferred` + `cite_evidence: <one-line>`. Verified ships authoritatively. Inferred triggers a coordinator-decision (dispatch Senna for grounding, accept on its face if low-severity, dismiss).

Generalised pattern: when an agent has dual responsibilities (OBSERVE + may-DIAGNOSE) and the failure mode is "downstream consumer cannot tell which claims are grounded vs which are inferred":

- **Wrong fix:** remove the capability for the second responsibility. Discards good output as collateral.
- **Right fix:** tag every output with its provenance. Make the trust contract machine-readable in the artifact itself.

Two corollaries:

1. **Capability removal is brittle to back-doors.** Even with `Read` removed, an agent with `Bash` can `cat` a file. With `Grep` removed, she can `Bash grep`. The OBSERVE-only fix would have needed a follow-on PreToolUse Bash matcher — escalating complexity. Citation-tagging needs zero new hooks; it's a prompt-layer rule with optional pr-lint extension.

2. **Capability removal masks coordinator failures.** PR #32's incident was not "Akali fabricated"; it was "Sona verified against the wrong head." Removing Akali's `Read` would have hidden that coordinator-side bug entirely — Akali would have had nothing to cite, Sona would have had no head-mismatch to detect, and the next time the same coordinator-discipline failure landed in a different shape, we'd ship a second fix.

Coupled lesson: when a coordinator retracts a framing mid-flight after you've drafted under the original framing, **do targeted Edits on §Context + load-bearing decision sections rather than a full rewrite**. The structural concerns usually still stand on their own architectural merit; only the evidence narrative needs reframing. Test plan, OQ block, references list usually need only minor touches.

Filed at: `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` (D2 + §Context fully reflect the corrected framing).
