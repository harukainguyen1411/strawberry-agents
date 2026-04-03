# Tasklist Handover

## Seraphine's UI/UX Changes (2026-04-03)

### Already implemented in `tasklist.html`
- **Task count badges** — day column headers show active task count
- **Better card spacing** — padding increased from 8px to 10px, description font from 0.72rem to 0.76rem, card gap from 4px to 6px
- **Today column emphasis** — subtle purple background tint (`#fafaff`) + enhanced box-shadow
- **Status dropdown overflow fix** — dropdowns near right edge get `align-right` class to prevent clipping
- **Mobile drag handle** — increased opacity (0.5) and font size (0.9rem) for better touch affordance
- **Empty state text** — changed to "Nothing scheduled" with italic styling

### Approved improvements (not yet implemented)
Priority order — Duong approved all of these:

1. **Done tasks in day column** — show completed tasks at bottom of each day, not in separate Done section. Duong's #1 request.
2. **Bigger drag target** — current handle is too small. Duong's #2 request.
3. **Color-coded left border** — 3px left border matching status color for at-a-glance scanning
4. **Auto-scroll to today on mobile** — programmatically scroll to today's column on load
5. **Quick-add input** — replace "+ Add" with inline text field (skip "New task" placeholder step)
6. **Undo delete toast** — replace `confirm()` with 5-second undo toast
7. **Drag preview cleanup** — cleaner ghost card, remove 2deg rotate on touch clone
8. **Overdue indicator** — subtle warning for tasks in-progress 3+ days
9. **Persist week in URL** — `?week=2026-W14` query param
10. **Filter/search** — search box in header
11. **Due date badge** — optional date pill on cards
12. **Print/export** — print stylesheet or copy-as-markdown
13. **Dark mode** — `prefers-color-scheme` support
14. **Card move animations** — FLIP transitions instead of full re-render

### Dropped by Duong
- Keyboard shortcuts — no need
- Collapse/expand columns — no need
- Subtasks/checklist — no need

### Design notes
- CSS variables are in `:root` — extend them for dark mode
- Status colors: todo=#9ca3af, inprogress=#3b82f6, onhold=#f97316, done=#22c55e
- Mobile breakpoint at 768px, small mobile at 480px
- The `tag` field on tasks controls whether title renders as a monospace badge (Linear tickets) or editable text
- Carry-forward logic (Ekko's) runs on load — moves stale todo/inprogress tasks to today

---

## Ekko's Server/Data Changes (2026-04-03)

### What's done
- **Server path fix** — `tasklist-server.js` (workspace version) was pointing to `agents/main-agent/sona/tasklist.json` (wrong). Fixed to `agents/sona/tasklist.json`.
- **Carry-forward logic** — added `carryForward()` in `tasklist.html`. On page load, any todo/inprogress tasks with dates before today auto-move to today's date. If connected to server, auto-saves the updated dates.
- **Deploy-ready server** — `server.js` in this folder is adapted for Fly.io. Uses `DATA_DIR` env var (defaults to `/data`) for JSON persistence on a Fly volume. Port via `PORT` env var.
- **Dockerfile** — Node 20 Alpine, copies server.js + tasklist.html, exposes 8080.
- **fly.toml** — app `mmp-tasklist`, region `ams`, persistent volume mount at `/data`, auto-stop/start machines.

### What's left (for Irelia)
1. **Initial Fly.io deploy** — run these commands from this directory:
   ```
   fly apps create mmp-tasklist --org personal
   fly volumes create tasklist_data --region ams --size 1
   fly deploy
   ```
   App will be live at `mmp-tasklist.fly.dev`.

2. **Seed initial data** — after deploy, PUT the task JSON to `/api/tasks` to populate. Or let it start empty and add tasks via the UI.

3. **CI/CD (optional)** — set up GitHub Actions to auto-deploy on push. Needs `FLY_API_TOKEN` secret in the repo.

4. **Sync mechanism** — currently the workspace `agents/sona/tasklist.json` and the Fly.io `/data/tasklist.json` are separate. If Sona needs to read/write tasks, she'd need to hit the Fly.io API instead of local disk.

### Architecture
```
tasklist.html (UI) → fetch /api/tasks → server.js → /data/tasklist.json (Fly volume)
                   ← JSON response   ←            ←
```

### File list
| File | Purpose |
|---|---|
| `server.js` | Node HTTP server — serves HTML + read/write JSON API |
| `tasklist.html` | Single-page UI — week-view kanban with drag-drop, inline edit, status changes, carry-forward |
| `Dockerfile` | Container build for Fly.io |
| `fly.toml` | Fly.io deployment config |
| `HANDOVER.md` | This file |

### Gotchas
- **Must access via server** — opening `tasklist.html` directly from filesystem won't work (API calls fail). Always use `http://localhost:3847` or the Fly.io URL.
- **Server restart needed after code changes** — the running Node process doesn't hot-reload. Kill and restart.
- **Carry-forward is one-way** — tasks moved to today can't auto-move back to their original date. Drag to reschedule.
- **No auth** — anyone with the URL can read/write tasks. Add auth if exposing publicly long-term.
