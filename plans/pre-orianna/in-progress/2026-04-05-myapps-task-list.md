---
status: in-progress
owner: swain
---

# B3: Myapps Task List — Implementation Plan

**Goal:** Ship a working task list feature in myapps that Duong and Evelynn can both use.
**Scope:** One sprint. Complete and ship what's already started.

---

## Current State

The TaskList feature is **substantially built**. Before writing any code, read the existing files:

| File | Status |
|---|---|
| `src/views/TaskList/types.ts` | Complete — Task type, status/priority enums, constants |
| `src/stores/taskList.ts` | Complete — Full CRUD, Firestore + localStorage, undo, carry-forward |
| `src/views/TaskList/Dashboard.vue` | Complete — loads store, renders WeekGrid |
| `src/views/TaskList/TaskListLayout.vue` | Complete — header, dark mode, UndoToast |
| `src/components/TaskList/WeekGrid.vue` | Complete — 7-day grid, week nav, on-hold section, drag/drop |
| `src/components/TaskList/DayColumn.vue` | Complete — day column, add button, drag-over |
| `src/components/TaskList/TaskCard.vue` | Complete — inline edit, status dropdown, priority, delete, drag+touch |
| `src/components/TaskList/UndoToast.vue` | Complete — undo for delete and status changes |
| `src/router/index.ts` | Complete — `/task-list/dashboard` route registered |
| `src/views/Home.vue` | Complete — task-list card on home page |
| `firestore.rules` | Complete — `users/{userId}/**` rule covers tasks |
| `firestore.indexes.json` | Partial — has updatedBy+updatedAt index; may need createdAt index |

**Do not rebuild what exists.** Your job is to complete the gaps below.

---

## Tech Stack

- **Framework:** Vue 3 + TypeScript (Composition API, `<script setup>`)
- **State:** Pinia (`useTaskListStore`)
- **Firestore:** Firebase v9 modular SDK — collection path `users/{uid}/tasks`
- **Styling:** Tailwind CSS (utility classes, dark mode via `dark:` prefix)
- **Routing:** Vue Router — routes already registered
- **i18n:** `vue-i18n` — keys in `src/i18n/locales/en.json` and `vi.json`

---

## Data Model

Collection: `users/{uid}/tasks`

```
Task {
  id: string                        // Firestore doc ID
  title: string                     // Required
  description: string               // Optional freeform
  status: 'todo' | 'inprogress' | 'onhold' | 'done'
  priority: 'high' | 'medium' | 'low'
  date: string                      // YYYY-MM-DD — which day the task belongs to
  tag: boolean                      // If true, renders as a label/tag badge
  createdAt: Timestamp
  updatedAt: Timestamp
  updatedBy: 'duong' | 'evelynn'    // Who last mutated it
  source: 'app' | 'evelynn'        // How it was created
  notes?: string                    // Free-form note, shown in violet italic
  category?: string                 // Optional grouping label (not yet exposed in UI)
  _deleted?: boolean                // Soft-delete flag (filtered out on load)
}
```

---

## UI Components (existing)

```
TaskListLayout        ← wrapper: header, dark toggle, UndoToast
  Dashboard           ← loads store on mount, renders WeekGrid
    WeekGrid          ← week nav (prev/next/today), 7×DayColumn, on-hold section
      DayColumn       ← day header, task cards, add button, drop zone
        TaskCard      ← inline title/desc edit, status dropdown, priority dot, delete
      UndoToast       ← teleported toast for undo actions
```

---

## Gaps to Complete

### 1. Real-time Firestore listener (REQUIRED)

**Why it matters:** The store currently uses `getDocs` (one-time fetch). Evelynn writes tasks via her MCP tools, but Duong's browser won't see changes without a page refresh.

**File:** `src/stores/taskList.ts`

**Change:** Replace the `loadFromFirestore()` function with an `onSnapshot` listener. Wire it up in `load()` and clean up on store unmount.

```ts
// Replace getDocs pattern with onSnapshot:
import { onSnapshot } from 'firebase/firestore'

let unsubscribe: (() => void) | null = null

async function load() {
  if (isLocal.value) {
    loadLocal()
    carryForward()
    return
  }
  loading.value = true
  const q = query(getCollection(), orderBy('createdAt', 'desc'))
  unsubscribe = onSnapshot(q, (snapshot) => {
    tasks.value = snapshot.docs
      .filter(d => !d.data()._deleted)
      .map(d => { /* same mapping as existing loadFromFirestore */ })
    loading.value = false
    const movedTasks = carryForward()
    if (movedTasks.length > 0) saveTasks(movedTasks)
  })
}

function cleanup() {
  if (unsubscribe) { unsubscribe(); unsubscribe = null }
}

// Return cleanup from the store so components can call it on unmount
return { ..., cleanup }
```

Call `store.cleanup()` in `Dashboard.vue` `onUnmounted`.

### 2. Firestore index for createdAt (REQUIRED)

The query `orderBy('createdAt', 'desc')` on a subcollection requires an index if combined with other filters in future. Add a single-field index to be safe.

**File:** `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "tasks",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "updatedBy", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "tasks",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "_deleted", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

Deploy indexes: `firebase deploy --only firestore:indexes` (Duong must run this).

### 3. E2E test (REQUIRED)

**File:** `e2e/task-list.spec.ts`

Write a Playwright test that:
1. Navigates to `/task-list/dashboard`
2. Authenticates in local mode (see `e2e/auth-local-mode.spec.ts` for the pattern)
3. Adds a task to today's column
4. Edits the title inline
5. Changes status to "In Progress"
6. Deletes the task and verifies undo toast appears
7. Clicks Undo and verifies task is restored

Use `localStorage` to seed local mode data instead of Firestore for test isolation.

### 4. Missing i18n keys (MINOR)

**Files:** `src/i18n/locales/en.json`, `src/i18n/locales/vi.json`

Add any missing keys under `taskList`. The layout uses `$t('taskList.title')` and `$t('taskList.subtitle')` — both exist. Verify no other `$t('taskList.*')` calls are missing.

---

## Implementation Steps

Follow in order. Mark each complete before moving to next.

**Step 1 — Read and understand existing code**
Read all files listed in "Current State" above. Do not skip this. You need to understand the existing implementation before making changes.

**Step 2 — Add real-time listener to taskList store**
Edit `src/stores/taskList.ts`:
- Add `onSnapshot` import
- Add `unsubscribe` ref at store scope
- Replace `loadFromFirestore` body with `onSnapshot` subscription
- Return `cleanup` from the store
- Update `Dashboard.vue` to call `store.cleanup()` in `onUnmounted`

**Step 3 — Update firestore.indexes.json**
Add the `_deleted + createdAt` index as shown above.

**Step 4 — Write E2E test**
Create `e2e/task-list.spec.ts` following the pattern in `e2e/auth-local-mode.spec.ts` and `e2e/forms-crud.spec.ts`.

**Step 5 — Run tests locally**
```
cd apps/myapps
npm run test:unit   # Vitest unit tests
npm run test:e2e    # Playwright e2e (requires running app)
```
Fix any failures before proceeding.

**Step 6 — Build check**
```
cd apps/myapps
npm run build
```
Confirm no TypeScript errors.

**Step 7 — Commit and open PR**
```
git add apps/myapps/src/stores/taskList.ts
git add apps/myapps/src/views/TaskList/Dashboard.vue
git add apps/myapps/firestore.indexes.json
git add apps/myapps/e2e/task-list.spec.ts
git commit -m "feat(task-list): real-time sync, indexes, e2e tests"
```
Open PR against `main`. Set `Author: katarina` or whichever agent implements this.

---

## Out of Scope (this sprint)

- Category filter UI — the `category` field exists in the data model but no UI is needed yet
- Evelynn MCP task tools — already implemented separately (`mcp__evelynn__task_*`)
- AppHeader nav link — navigation to task list is via the Home page card; direct nav link is a future enhancement
- Notes editing UI — notes from Evelynn are displayed read-only in TaskCard; that's sufficient for now

---

## Success Criteria

- [ ] Task list loads from Firestore in real time (changes from Evelynn appear without refresh)
- [ ] Duong can create, edit title/description, change status, change priority, delete tasks
- [ ] Undo works for delete and status changes (5s window)
- [ ] Overdue tasks carry forward to today on load
- [ ] On-hold tasks appear in the On Hold section below the grid
- [ ] Works in both local mode and authenticated mode
- [ ] E2E test passes in CI
- [ ] Build passes with no TypeScript errors

---

## Who Executes This

**Katarina** or **Ornn** (Sonnet-tier execution agents). Lissandra reviews the PR.
Evelynn coordinates. Do not start without Evelynn's delegation message.
