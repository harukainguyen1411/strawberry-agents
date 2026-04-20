# Managed Agent Dashboard Tab ADR — gotchas

## Twin ADRs must name-lock the shared module

This ADR (dashboard tab) and the lifecycle ADR both consume the same Anthropic SDK surface. The brief explicitly required reusing `managed_session_client.py` across both. Resolution: cite the exact filename in both ADRs, and in the handoff section call out that decomposition must land ONE module, not two parallel copies. Without this, Kayn and Aphelios could easily each produce a wrapper with slightly divergent signatures.

Lesson: when two ADRs share a dependency, name it identically in both and require handoff coordination. Don't rely on implementers to notice the overlap.

## "Human surface" vs. "automated surface" justifies ADR split

The brief pre-framed why this is separate from the lifecycle ADR. I made that framing the lead of §1 context — operator tool (see, click, terminate) vs. automated monitor (warn, auto-kill). Same API, different consumers, different failure modes (UI error banners vs. Slack alerts), different security posture (destructive human action vs. idempotent background delete). Worth documenting the separation so future readers don't ask "why two ADRs".

## Degraded fields must be reflected in the wire format, not hidden

Spike 1 from the lifecycle ADR could return "idle time not available from Anthropic". The temptation is to paper over that in the UI with `—`. I added `degradedFields: [...]` to the API response and a header pill in the UI so operators know when they're looking at a degraded view. Hiding degradation = silent wrongness.

## Auth-posture question deserves an explicit Open Question, not an assumption

The dashboard's current auth posture was unspecified. Terminate is destructive. I flagged Q4 ("dashboard auth posture") rather than assuming Cloud Run IAM protects it, and proposed a shared-secret-header interim mitigation. Pattern: when a destructive new route inherits existing guards, explicitly verify those guards exist — don't assume.

## Confirmation-modal copy is a real design decision, not boilerplate

Listed Q1 with proposed copy including the type-to-confirm gate. Operators terminate rarely; when they do it's high-consequence. The copy either prevents misclicks or enables them. Worth surfacing to Duong/Lulu rather than letting the implementer pick ad-hoc strings.

## Orphan-default-visibility is a philosophical question

Q2 asks whether orphans show by default. For-case: the whole value prop of this tab is seeing what the scanner misses. Against-case: if the scanner is doing its job, orphans are noise. I stated a lean (show by default, tagged) and asked Duong to confirm rather than silently picking. Pattern from the session-API ADR: pick a default and surface the choice, don't punt silently.

## Cache invalidation on action, not just TTL

10s TTL list cache is fine for read traffic. But after a terminate, the old cache would show a "terminated" row for up to 10s. Explicit invalidation on action (§6) prevents stale UI right after the consequential click. Pattern: any cache that backs a UI with write actions needs write-invalidation in addition to TTL.
