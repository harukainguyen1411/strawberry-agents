# Firestore Conversation Turn Ordering

## Context
When a Cloud Function manages a multi-turn chat in Firestore, synthetic or injected
messages (e.g. token budget warnings) must NOT be appended to Firestore as user turns
if the real user message hasn't been persisted yet. Doing so creates two consecutive
user-role messages in the conversation history, which violates Gemini's alternating
role expectation and produces confusing chat state.

## Pattern
- Persist the real user message to Firestore first.
- Inject synthetic instructions (force-spec prompts, budget warnings) into the
  in-memory `convMessages` array only — after the real user message is in the array.
- Never append synthetic user turns to Firestore.

## Applied in
- `beeIntake.ts` `beeIntakeTurn` — L1 fix on PR #105 (2026-04-14).
