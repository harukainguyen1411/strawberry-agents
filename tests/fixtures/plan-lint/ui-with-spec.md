---
status: proposed
concern: personal
owner: seraphine
created: 2026-04-25
tests_required: true
complexity: normal
tags: [frontend, ui-ux]
---

# UI Feature: Widget redesign

## Context

Redesign the main widget.

## Decision

Implement new widget layout using Vue components.

## UX Spec

<!-- path-glob: apps/**/src/**/*.{vue,tsx,jsx,ts,js,css,scss}, apps/**/components/**, apps/**/pages/**, apps/**/routes/** -->

### User flow

1. User lands on dashboard route `/dashboard`
2. Widget renders with default state
3. User clicks widget to expand details

### Component states

- `default` — widget shows summary count
- `hover` — border color shifts to `--color-primary-hover`
- `focus` — visible focus ring per Rule 22 D5
- `loading` — skeleton placeholder shown
- `error` — inline error message with retry button
- `empty` — empty-state illustration with call-to-action

### Responsive behavior

| Breakpoint | Layout |
|---|---|
| mobile (< 640px) | single-column, widget full-width |
| tablet (640–1024px) | two-column grid |
| desktop (> 1024px) | three-column grid |

### Accessibility

- Tab order: widget container → expand button → detail list items
- ARIA: `role="region"` on widget, `aria-label="Widget: <title>"`, `aria-expanded` on toggle
- Contrast: body text uses `--color-text-primary` (ratio 7:1 against `--color-bg-surface`)
- Focus ring: visible on `:focus-visible` using `outline: 2px solid var(--color-focus-ring)`
- Motion-reduce: expansion animation suppressed under `prefers-reduced-motion: reduce`
- Screen-reader name+role: every interactive element has explicit `aria-label`

### Figma link

Figma: https://figma.com/file/example/Widget-Redesign?node-id=1%3A1

### Out of scope

- Widget drag-and-drop reordering (deferred to separate plan)
- Widget custom colour themes
- Keyboard shortcut overlay

## Tasks

- [ ] **T1** — Implement new widget. Files: `apps/web/src/components/Widget.vue`.
- [ ] **T2** — Add widget styles. Files: `apps/web/src/components/Widget.scss`.

## Test plan

Unit tests for widget component.
