---
status: approved
concern: personal
owner: seraphine
created: 2026-04-25
complexity: standard
---

# Test fixture: UI plan WITH §UX Spec

## Context

Fixture for uxspec-gate hook tests. Represents a UI-touching plan that
CONTAINS the required §UX Spec section with non-empty body.

## Decision

Add a new component with design spec.

## UX Spec

### User flow

1. User visits `/dashboard` — sees the Button component in the toolbar.
2. User clicks Button — action fires.

### Component states

- `default`: blue background, white label
- `hover`: darker blue background
- `focus`: visible focus ring, 2px offset
- `disabled`: grey background, `aria-disabled=true`
- `loading`: spinner icon, button non-interactive

### Responsive behavior

| Breakpoint | Layout |
|---|---|
| mobile (<768px) | full-width |
| tablet (768-1024px) | fixed 200px |
| desktop (>1024px) | fixed 200px |

### Accessibility

- Keyboard: focusable via Tab, activated via Space/Enter
- ARIA: `role="button"` (native `<button>` element), `aria-label` on icon-only variant
- Color contrast: text #fff on #0066cc meets 4.5:1 AA
- Focus visible: `:focus-visible` ring shown
- Motion-reduce: no animation in reduced-motion mode

### Figma link

Figma: https://figma.com/file/fixture-button-component

### Out of scope

- Icon variants beyond the spinner
- Dark mode

## Tasks

- [ ] T-1 — implement `apps/frontend/src/components/Button.vue`. estimate_minutes: 30.
- [ ] T-2 — style `apps/frontend/src/components/Button.scss`. estimate_minutes: 15.
