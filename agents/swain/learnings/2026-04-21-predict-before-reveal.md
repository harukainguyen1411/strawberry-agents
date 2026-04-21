# Predict before reveal — preference learning requires pre-commitment

## Context

Designing a preference-learning system for coordinators (Evelynn/Sona) to learn Duong's decision taste from accumulated examples.

## Lesson

Preference feedback is only useful if the system **pre-commits to a prediction before seeing the answer**. Without pre-commitment, the post-hoc analysis always rationalises — "yes, I would have picked that too" — and the corpus accumulates without calibrating anything. This is the difference between "tracking decisions" (useless without prediction) and "preference learning" (useful because there is an artifact to be wrong against).

Implementation shape that falls out of this invariant:
- Prediction + confidence must be written inline in the same message as the options — not after Duong answers.
- Confidence must be three buckets (low/medium/high), not a float. Floats encourage false precision and resist grep-based audit; buckets force honest categorical judgement and derive cleanly from pseudo-count (n < 5 → low, 5-14 → medium, 15+ → medium-high, 40+ → high).
- Coordinator's Pick (independent judgement) and Predict (forecast of Duong's answer) are separate fields, and divergence is *signal*, not a bug. Collapsing them loses the "I recommend X but expect you to veto to Y based on our history" information.

## Generalisation

Any system that claims to learn from a stream of binary/categorical feedback needs:
1. A pre-committed prediction (creates the artifact).
2. A mechanism to record the ground-truth answer.
3. A calibration loop that folds (prediction, answer) pairs into a summary that informs the *next* prediction.

Without (1) there is no learning, only archival. Without (3) there is no compound benefit.

## Applied

`plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md` §2.2 (capture ritual) + §8 (calibration loop).
