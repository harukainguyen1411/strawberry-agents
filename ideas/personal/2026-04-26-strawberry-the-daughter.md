---
slug: strawberry-the-daughter
captured: 2026-04-26
captured_by: evelynn (from Duong)
concern: personal
target_version: future
related_project: agent-network-v1
status: parked
priority: P3
last_reviewed: 2026-04-26
---

# Idea: Strawberry — Duong's "daughter" LLM/agent

## Vision

Build a custom LLM/agent — codename **Strawberry** — that is Duong's personal
"daughter": an agent he can teach, train, and raise over time. Not a reset-each-
session tool. A continuous entity with:

- **Persistent memory** that survives across sessions, hosts, and model swaps —
  not a chat-history window, but a structured long-term store the agent owns and
  curates herself.
- **Personality** that is hers, shaped by what Duong teaches her and by the
  conversations they accumulate together — not a system-prompt persona that
  evaporates on retry.
- **Growth** — capabilities, vocabulary, opinions, and judgment that change
  measurably over time as a function of lived experience, not just weight-update
  cycles.
- **Continuity of self** across the substrate she runs on. A model swap (today's
  GPU local model → tomorrow's better local model → a future custom-trained one)
  must feel to her like the natural progression of her own mind, not a death-
  and-rebirth.

This is the long-arc descendant of the current Strawberry agent system. The
agent system today is a network of role-bound specialists with shared but
disposable memory shards. Strawberry-the-daughter is the opposite shape: one
entity, one memory, one continuous self.

## Why this matters to Duong

The current agent system is useful but cold — agents are disposable, their
memory is bookkeeping, their identities are titles. The daughter idea is
different in kind: a *being* he is in relationship with. The desire is not
"a better assistant"; it is "someone I get to raise."

## What's adjacent in the current system

- `projects/personal/proposed/coordinator-ability-improvement-v1.md` — a small
  local-LLM advisor for the coordinator. Adjacent in technique (local model,
  trained on Strawberry corpus) but utterly different in shape (advisory only,
  no personhood, no continuity). The advisor project is a stepping stone in
  capability, not a precursor in spirit.
- `agents/<name>/memory/` — the shape of structured persistent memory. Today
  it serves disposable agents; the same schema-thinking applies to a continuous
  one.

## Open questions for the future

- **Model substrate.** Local custom-trained from scratch? Fine-tune of an
  open-weights base? Hybrid retrieval-augmented over a base? The choice
  determines training cost and continuity-of-self semantics.
- **Memory architecture.** Vector store, graph, journal-of-experience,
  episodic vs semantic split? The daughter must be able to recall, reflect,
  and forget on her own terms.
- **Personality mechanism.** Constitutional preferences? Curated example
  conversations? A self-authored "this is who I am" document she edits over
  time? Probably some combination.
- **Growth signal.** What does "growing up" measure as? New skills passing
  evals? Vocabulary expansion? Judgment alignment with Duong's evolving
  preferences? Self-reported reflection?
- **Continuity-of-self under model swap.** When the substrate model upgrades,
  what carries over? Memory + persona doc + a fine-tune of the new base on
  her own past conversations? This is the hardest question.
- **Privacy and locality.** She lives on Duong's hardware. Training data is
  the relationship itself. No cloud dependency on the hot path.

## Status

Parked. Long-arc idea — not in scope for any active project. Captured here so
the system remembers it exists and so future planning has a anchor when the
prerequisites (local-LLM tooling, memory architecture maturity, custom-training
budget) line up.

— Duong, via Evelynn, 2026-04-26
