---
title: Dark Strawberry Icon Picker System
status: approved
owner: syndra
created: 2026-04-12
---

# Dark Strawberry Icon Picker System

## Problem

When users request a custom app through Discord, they need a way to choose or customize an icon for it. Currently apps use emoji placeholders (the landing page shows them). The platform needs an SVG-based icon system that feels on-brand and scales as the app catalog grows.

## Decision: Curated Library + Color Customization

**Rejected alternatives:**

- **User uploads:** Unpredictable quality, moderation burden, storage cost, inconsistent visual identity. Not worth it at this scale.
- **Full icon builder (compose from parts):** Over-engineered for the use case. Users want to pick an icon, not design one. Building a composable icon editor is a product in itself.
- **Host our own from scratch:** Massive upfront cost for a small catalog. No reason to draw 200+ icons when good open-source sets exist.

**Chosen approach:** Use Lucide Icons (open-source, MIT, SVG, 1500+ icons, actively maintained, tree-shakable) as the base library. Layer on Dark Strawberry's brand through color customization and a curated subset for the picker UI.

### Why Lucide

- MIT license, no attribution required in UI
- SVG-native, consistent 24x24 grid, stroke-based (easy to recolor)
- Already has a Vue 3 package (`lucide-vue-next`) — drops into the existing stack
- 1500+ icons means users will find something relevant for any app concept
- Stroke-based design means color customization is trivial (one CSS property)

## Architecture

### Component: `IconPicker.vue`

A modal/popover component with:

1. **Search** — text search across icon names and tags (Lucide provides metadata)
2. **Categories** — curated groups: Productivity, Finance, Health, Social, Media, Dev, Misc
3. **Color picker** — 8-10 preset brand colors (derived from Dark Strawberry palette: deep red, accent pink, muted purple, teal, amber, etc.) plus a custom hex input
4. **Preview** — live preview of selected icon + color on a dark card (mimicking how it will look in the apps portal)
5. **Output** — stores as `{ icon: "book-open", color: "#e040a0" }` in Firestore

### Data model

```
apps/{appId}/icon: {
  name: string,        // Lucide icon name, e.g. "book-open"
  color: string,       // Hex color, e.g. "#e040a0"
  custom_svg?: string, // Optional: inline SVG string for custom-requested icons
}
```

Minimal footprint. No binary storage. Preset icons render client-side from Lucide using name + color. Custom icons render from the inline SVG string. The `<AppIcon>` component checks `custom_svg` first, falls back to Lucide `name`.

### Rendering

Everywhere an app icon appears (portal home, nav, app header), render via a shared `<AppIcon>` component:

```vue
<AppIcon :name="app.icon.name" :color="app.icon.color" :size="32" />
```

This component wraps Lucide's dynamic icon rendering. Fallback: if no icon is set, show a styled first-letter avatar (already a common pattern).

### Integration points

1. **"Request your app" flow** — after describing the app in Discord, Duong (or a bot) sends a link to a lightweight icon picker page. User picks icon + color, result saved to Firestore under the app doc. Alternative: Duong picks a default, user can change it later in Settings.
2. **Apps portal home** — replace emoji placeholders with `<AppIcon>` components
3. **Landing page** — out of scope. Landing page keeps Neeko's hand-crafted static SVGs; this system is apps-portal-only.

## Phases

### Phase 1: Foundation (MVP)

- Install `lucide-vue-next`
- Build `<AppIcon>` wrapper component
- Add `icon` field to app Firestore documents
- Replace emoji icons in portal home with `<AppIcon>`
- Migrate existing 3 apps to use Lucide icons (book-open, trending-up, check-square)
- Default palette: 8 brand colors hardcoded

### Phase 2: Picker UI (Preset Library)

- Build `<IconPicker>` modal component (search + category grid + color selection + preview)
- Curate category groupings (tag ~200 most relevant icons into 7 categories)
- Integrate picker into app Settings page (users can change their app icon anytime)
- Integrate picker into the app request flow — user selects an icon when requesting an app via Discord link or future web form

### Phase 3: Custom Icon Requests

- Add a "Request custom icon" option inside the picker — if nothing in the preset library fits, the user describes what they want
- Custom icon requests route to Discord (same channel as app requests) or a simple text input stored in Firestore
- Duong (or agent system) creates a custom SVG matching the brand style and adds it to the user's app
- Custom icons are stored as inline SVG strings in Firestore under the app doc (field: `icon.custom_svg`) — the `<AppIcon>` component checks for `custom_svg` first, falls back to Lucide `name`

### Phase 4: Polish (optional, future)

- Custom background shapes (circle, rounded square, hexagon) behind the icon
- Gradient color support (two-color gradients from the brand palette)
- "Recently used" and "Popular" sections in the picker
- Promote frequently-requested custom icons into the preset library
- Icon pack expansion: allow additional icon sets beyond Lucide if needed

## Open Questions for Duong

1. ~~**Who picks the icon — the user or you?**~~ **Resolved:** Users pick from a preset Lucide library. If they want something custom, they request it — Duong/agents create a bespoke SVG.
2. ~~**Landing page icons**~~ **Resolved:** Landing page keeps Neeko's hand-crafted static SVGs. The icon picker system is apps-portal-only.
3. ~~**Priority**~~ **Resolved:** Icon picker work begins after the current platform buildout (Phase 2 of Dark Strawberry). Not a launch blocker.

## Dependencies

- `lucide-vue-next` package (MIT, ~50KB tree-shaken for 200 icons)
- Firestore schema update (add `icon` field to app documents)
- No backend changes — entirely client-side rendering
