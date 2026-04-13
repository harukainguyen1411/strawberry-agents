---
status: approved
owner: swain
created: 2026-04-13
---

# Feature Flags via Firebase Remote Config

## Goal

Replace the hardcoded app list in `Home.vue` with a dynamic, per-user visibility system powered by Firebase Remote Config. Immediate use case: show the Bee app only to `harukainguyen1411@gmail.com`.

## Motivation

The Dark Strawberry portal (`apps/myapps`) hardcodes 3 apps in `Home.vue`. Bee exists but is invisible to everyone. We need per-user feature flags to control app visibility. Firebase Remote Config is the right choice: zero new infra, already on Firebase, has MCP tools for template management.

## Non-Goals

- Analytics-based user properties (too heavy for this use case).
- Server-side flag evaluation (unnecessary — client-side custom signals suffice).
- A/B testing or percentage rollouts (not needed yet).
- Changing any existing app's behavior or visibility.

---

## Flag Naming Convention

| Pattern | Use |
|---------|-----|
| `<feature>_visible` | Visibility toggle — controls whether a UI element renders |
| `<feature>_enabled` | Kill-switch — controls whether a feature functions |

All lowercase `snake_case`. Examples: `bee_visible`, `portfolio_tracker_enabled`.

---

## Implementation Steps

### Step 1: Add Remote Config to Firebase config

**File:** `apps/myapps/src/firebase/config.ts`

Import and initialize Remote Config alongside the existing services:

```ts
import { getRemoteConfig, type RemoteConfig } from 'firebase/remote-config'

// After `const app = initializeApp(firebaseConfig)`
export const remoteConfig: RemoteConfig = getRemoteConfig(app)

// Short interval for dev, 1 hour for prod
remoteConfig.settings.minimumFetchIntervalMillis =
  import.meta.env.DEV ? 10_000 : 3_600_000
```

No new npm dependency needed — `firebase/remote-config` ships with the `firebase` package (already at `^10.11.1`).

### Step 2: Set bootstrap defaults

**File:** `apps/myapps/src/firebase/remoteConfigDefaults.ts` (new)

```ts
/**
 * Default values for Remote Config parameters.
 * These are used when Remote Config has not yet fetched or fetch fails.
 * Safe defaults: new/gated features default to OFF.
 */
export const remoteConfigDefaults: Record<string, boolean> = {
  bee_visible: false,
}
```

Apply defaults in `config.ts` after creating `remoteConfig`:

```ts
import { remoteConfigDefaults } from './remoteConfigDefaults'

remoteConfig.defaultConfig = remoteConfigDefaults
```

### Step 3: Create `useFeatureFlag` composable

**File:** `apps/myapps/src/composables/useFeatureFlag.ts` (new)

```ts
import { ref, type Ref } from 'vue'
import {
  fetchAndActivate,
  getValue,
  type RemoteConfig,
} from 'firebase/remote-config'
import { remoteConfig } from '@/firebase/config'

const fetched = ref(false)
const fetchPromise: Promise<void> | null = null

/**
 * Fetch and activate Remote Config values.
 * Safe to call multiple times — deduplicates via `fetchPromise`.
 */
export async function fetchFeatureFlags(): Promise<void> {
  if (fetched.value) return
  try {
    await fetchAndActivate(remoteConfig)
  } catch (e) {
    console.warn('[RemoteConfig] fetch failed, using defaults', e)
  } finally {
    fetched.value = true
  }
}

/**
 * Returns a reactive boolean ref for a given Remote Config flag key.
 * Before fetch completes, returns the default value from remoteConfigDefaults.
 * After fetch, returns the resolved server value.
 */
export function useFeatureFlag(key: string): Ref<boolean> {
  const flag = ref(getValue(remoteConfig, key).asBoolean())

  // Re-evaluate after fetch completes (in case called before fetch)
  if (!fetched.value) {
    fetchFeatureFlags().then(() => {
      flag.value = getValue(remoteConfig, key).asBoolean()
    })
  }

  return flag
}
```

### Step 4: Set custom signals on auth state change

**File:** `apps/myapps/src/firebase/remoteConfigSignals.ts` (new)

Custom signals tell Remote Config who the current user is, enabling per-user targeting in the console.

```ts
import { onAuthStateChanged } from 'firebase/auth'
import { setCustomSignals } from 'firebase/remote-config'
import { auth } from './config'
import { remoteConfig } from './config'
import { fetchFeatureFlags } from '@/composables/useFeatureFlag'

/**
 * Call once at app startup (e.g. in main.ts or App.vue onMounted).
 * Sets custom signals whenever the user logs in/out, then re-fetches flags.
 */
export function initRemoteConfigSignals(): void {
  onAuthStateChanged(auth, async (user) => {
    await setCustomSignals(remoteConfig, {
      userEmail: user?.email ?? '',
      userUid: user?.uid ?? '',
    })
    // Re-fetch after signals change so conditions re-evaluate
    await fetchFeatureFlags()
  })
}
```

**Wire it up in `App.vue` or `main.ts`:**

```ts
import { initRemoteConfigSignals } from '@/firebase/remoteConfigSignals'

// In setup or onMounted:
initRemoteConfigSignals()
```

### Step 5: Refactor `Home.vue` app list

**File:** `apps/myapps/src/views/Home.vue`

Replace the hardcoded 3-app array with a complete registry. Each entry optionally declares a `flag` key. Apps without a `flag` are always visible.

```ts
import { computed, ref } from 'vue'
import { useFeatureFlag } from '@/composables/useFeatureFlag'

interface App {
  id: string
  name: string
  description: string
  icon: string
  route: string
  flag?: string  // Remote Config key — omit for always-visible apps
}

const allApps = ref<App[]>([
  {
    id: 'read-tracker',
    name: t('home.readTracker.name'),
    description: t('home.readTracker.description'),
    icon: '📚',
    route: '/myApps/read-tracker',
  },
  {
    id: 'portfolio-tracker',
    name: t('home.portfolioTracker.name'),
    description: t('home.portfolioTracker.description'),
    icon: '📈',
    route: '/myApps/portfolio-tracker',
  },
  {
    id: 'task-list',
    name: t('home.taskList.name'),
    description: t('home.taskList.description'),
    icon: '📋',
    route: '/myApps/task-list',
  },
  {
    id: 'bee',
    name: t('home.bee.name'),
    description: t('home.bee.description'),
    icon: '🐝',
    route: '/myApps/bee',
    flag: 'bee_visible',
  },
])

// Resolve flags — build a map of flag key → reactive boolean
const flagKeys = allApps.value
  .map((a) => a.flag)
  .filter((f): f is string => !!f)
const flags = Object.fromEntries(
  flagKeys.map((key) => [key, useFeatureFlag(key)])
)

const apps = computed(() =>
  allApps.value.filter((app) => {
    if (!app.flag) return true
    return flags[app.flag]?.value ?? false
  })
)
```

The template stays unchanged — it already iterates `apps`.

### Step 6: Create the Remote Config template via MCP

Use the Firebase MCP tool `remoteconfig_update_template` to create the parameter and condition. The implementing agent should:

1. First call `remoteconfig_get_template` to fetch the current template.
2. Merge the following additions into the existing template.
3. Call `remoteconfig_update_template` with the merged template (include the `etag` from the GET response).

**Condition to add:**

```json
{
  "name": "haruka_email",
  "expression": "device.customSignals['userEmail'] == 'harukainguyen1411@gmail.com'",
  "tagColor": "INDIGO"
}
```

**Parameter to add:**

```json
{
  "bee_visible": {
    "defaultValue": {
      "value": "false"
    },
    "conditionalValues": {
      "haruka_email": {
        "value": "true"
      }
    },
    "valueType": "BOOLEAN",
    "description": "Show Bee app in Home grid. Gated to Haruka's email."
  }
}
```

**Important:** Remote Config stores boolean values as strings `"true"` / `"false"`. The client SDK's `asBoolean()` handles the conversion.

### Step 7: Add i18n keys for Bee on Home page

**Files:** `apps/myapps/src/i18n/en.json` (and other locale files)

Add `home.bee.name` and `home.bee.description` keys. Example:

```json
{
  "home": {
    "bee": {
      "name": "Bee",
      "description": "Your personal assistant"
    }
  }
}
```

(Adjust description to match the actual Bee app purpose.)

---

## Acceptance Tests

| Scenario | Expected |
|----------|----------|
| Fresh incognito / not logged in | Home shows 3 apps (read-tracker, portfolio-tracker, task-list). No Bee. |
| Logged in as Duong (`duongntd99@gmail.com`) | Home shows 3 apps. No Bee. |
| Logged in as Haruka (`harukainguyen1411@gmail.com`) | Home shows 4 apps including Bee. |
| Flag `bee_visible` set to `false` for all conditions in console | Haruka sees 3 apps on next fetch (instant on reload in dev, up to 1h in prod). |
| Firebase Remote Config unreachable (e.g. offline) | Home shows 3 apps. Bee stays hidden (safe default). |

---

## Rollback

1. Revert the code changes — the hardcoded 3-app array returns.
2. Optionally delete the `bee_visible` parameter from the Remote Config template via MCP.
3. No data migration needed — this is purely additive.

---

## Deploy Order

1. Ship code with `bee_visible` default `false` (Bee invisible to all — safe deploy, no behavior change).
2. Create the Remote Config template (Step 6 above).
3. Verify Haruka sees Bee after logging in and reloading.
4. Confirm no other user sees Bee.

---

## Future Extensions

- Additional apps get a `flag` entry and a corresponding Remote Config parameter.
- Percentage rollouts or multi-condition targeting can be added per-parameter in the console without code changes.
- `<feature>_enabled` flags can gate functionality within apps (not just visibility on Home).
