---
slug: decision-capture-widget-v1
status: proposed
concern: personal
scope: [personal]
owner: duong
created: 2026-04-26
deadline: TBD
claude_budget: TBD
tools_budget: TBD
risk: TBD
user: duong-only
focus_on:
  - drastically reduce decision-capture friction (manual → one-click)
  - native macOS surface (widget / menu bar / system action)
  - zero coordinator-side overhead beyond authoring the question + options
  - faithful to the existing decision-log schema (no new format, no parallel store)
less_focus_on:
  - cross-platform (macOS-only for v1)
  - auto-classification of axes (coordinator still tags)
  - mobile / web surface
related_plans: []
---

# Project: decision-capture-widget-v1

## Goal

Replace the current manual decision-capture ritual — coordinator writes a temp
file, runs `bash scripts/capture-decision.sh <coordinator> --file <tmpfile>`,
parses the result — with a native macOS widget (or menu bar app, or shortcut
extension) where Duong sees the pending decision, taps his pick (a/b/c), and
the system auto-files the log entry to
`agents/<coordinator>/memory/decisions/log/`.

Today the flow is: coordinator presents a/b/c in chat → Duong types a letter →
coordinator writes a temp markdown file → coordinator shells out to the capture
script → script validates frontmatter → file lands. That sequence runs **on
every binding decision**, often multiple times per session. The coordinator
spends real time on it; Duong waits for it. Worse, the friction tempts both
sides to skip the log entirely on "small" decisions, eroding the
preference-learning signal that the decision-feedback system depends on.

A widget makes the pick a one-tap action. The coordinator still authors the
question, options, and frontmatter (that's the value-add). Everything after
Duong's tap is automated.

## Why

Three concrete pain signals from current sessions:

1. **Manual capture is slow.** Each decision costs ~30–60s of coordinator
   context just on the file-write + script-shell-out + frontmatter-error
   retry loop. Compounds across a session.
2. **Skipping erodes signal.** When the friction is high, the coordinator
   rationalizes "this one's small, skip the log." But the preference-learning
   roll-up in `agents/<coordinator>/memory/decisions/preferences.md` needs
   density of samples to be useful. Each skip is a hole.
3. **Frontmatter validation breaks flow.** The capture script rejects on
   missing `decision_id`, malformed `axes`, etc. The coordinator has to retry,
   re-edit the file, re-run. Pure plumbing tax.

The widget removes (1) and (3) outright and dramatically reduces (2) by
making capture cheaper than skipping.

## Definition of Done

A working macOS surface integrated end-to-end such that:

1. **Coordinator-side**: when a coordinator session presents a binding
   decision, it writes a structured pending-decision payload (yaml + markdown
   body) to a known queue location (e.g. `~/.strawberry/decisions/pending/`).
   Coordinator logic invokes the same authoring flow it does today; only the
   destination changes.
2. **Widget-side**: the widget polls (or watches via FS events) the queue
   location, surfaces pending decisions in a native UI with the question, the
   a/b/c options, the coordinator's `Pick:` recommendation, and the
   `Predict:` line.
3. **One-tap pick**: Duong taps an option. The widget writes
   `duong_pick: <letter>` into the payload, then invokes
   `scripts/capture-decision.sh <coordinator> --file <payload>` (or its
   library equivalent), and on success moves the payload to
   `~/.strawberry/decisions/captured/`.
4. **Coordinator notification**: after capture, the widget signals the
   coordinator session (e.g. by writing to a known stdin pipe / file the
   coordinator polls) so the coordinator can resume the decision-dependent
   work.
5. **Failure path**: if validation fails, the widget surfaces the error
   inline (not silently) and lets Duong either retry or escalate to the
   coordinator. No silent drops.
6. **No format drift**: the stored decision log entry is byte-identical to
   what the manual flow produces today — same frontmatter schema, same body
   sections, same path under `agents/<coordinator>/memory/decisions/log/`.

## Constraints

- **macOS-only for v1.** Native surface (SwiftUI widget, menu bar app, or
  Shortcuts action — pick at plan time).
- **Coordinator authors, widget routes.** The widget never invents a
  question, never selects on Duong's behalf. It is purely the input surface
  for the `duong_pick` field plus the runner of the existing capture script.
- **No new data store.** Decisions still land in
  `agents/<coordinator>/memory/decisions/log/` as today. The
  `~/.strawberry/decisions/{pending,captured}/` queue is ephemeral routing
  state, not durable storage.
- **Hands-off mode compatibility.** When the coordinator runs in hands-off
  auto-decide mode, the widget is bypassed entirely (the coordinator captures
  with `coordinator_autodecided: true` per current protocol).
- **Privacy.** Pending payloads may contain plan paths and reasoning; they
  live in `~/.strawberry/` (gitignored, machine-local) and are never
  transmitted off-machine.

## Open questions (resolve before plan authoring)

1. **Surface choice.** Native widget (lock-screen / Notification Center) vs
   menu bar app vs Shortcuts action vs hybrid. Trade-off: widgets refresh on
   a system-controlled cadence (low Duong-side friction, but laggy);
   menu bar is always-visible (more intrusive, instant).
2. **Coordinator → widget signaling.** FS-watch on
   `~/.strawberry/decisions/pending/` is simplest. Alternative: a tiny local
   daemon with a UNIX socket. The first is portable and zero-setup; the
   second is more reactive.
3. **Widget → coordinator signaling on pick.** How does the live coordinator
   session learn Duong picked? Options: poll the captured/ dir, watch a
   sentinel file, or read the existing `agents/<coordinator>/memory/decisions/log/`
   directory directly.
4. **Multiple pending decisions.** If two coordinator sessions are
   concurrently waiting (Evelynn + Sona, or two Evelynn sub-tasks), how
   does the widget present them? Stacked? Latest-only?
5. **Schema evolution.** When the decision frontmatter schema gains a new
   required field (it has happened twice already), the widget must learn
   the new field too. How is the schema versioned and shared between the
   coordinator's authoring code and the widget's input UI?
6. **Distribution.** Local build + manual install? Signed `.app` bundle?
   Mac App Store? Unsigned and self-built is fine for personal use but has
   Gatekeeper friction.

## Out of scope

- Cross-platform (Linux / Windows / iOS).
- Auto-suggesting axes or auto-classifying decisions — coordinator still
  tags axes manually.
- Replacing the markdown decision-log format with a database or SQLite store.
- Letting the widget invent decisions Duong didn't see in chat (the
  coordinator must always be the author).
- Aggregate visualizations / dashboards of historical decisions — the
  retro-dashboard already covers that surface.

## Notes

Adjacent systems:

- **Decision-capture skill / `scripts/capture-decision.sh`** — the existing
  CLI surface. The widget wraps and replaces the manual invocation; it does
  not reimplement the validation or file-write logic.
- **`decisions/preferences.md`** — the rollup the widget feeds into via the
  same script. Unchanged.
- **Coordinator deliberation primitive** (`_shared/coordinator-intent-check.md`)
  — the upstream gate that decides _whether_ a decision is binding enough to
  log. The widget only surfaces what the coordinator chose to log.
- **Hands-off auto-decide mode** — already bypasses Duong; the widget is a
  no-op in that mode.

The shape of the widget's input UI should preserve the current
`Pick: / Predict: / Confidence:` framing so the learning signal stays
honest — Duong sees the coordinator's prediction *before* picking, so the
`predict-vs-actual` axis stays measurable.
