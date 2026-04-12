---
title: Dark Strawberry — Platform Architecture
status: proposed
owner: swain
date: 2026-04-12
tags: [architecture, platform, darkstrawberry]
---

# Dark Strawberry — Platform Architecture

## Context

Dark Strawberry is Duong's AI-powered app platform where he builds custom apps for people. The current codebase is a single Vue 3 SPA (`apps/myapps/`) backed by one Firebase project with one Firestore database. All app data lives under `users/{userId}/{collection}` with no concept of app-level isolation, ownership, or access control beyond Firebase Auth.

This plan redesigns the data model, access layer, and monorepo structure to support: public apps (myApps), personal apps (yourApps), per-app database isolation, collaboration, and forking — all on Firebase/GCP free tier.

## Monorepo Structure

```
apps/
  platform/                  # The Dark Strawberry shell (auth, routing, app registry, settings)
    src/
      core/                  # Auth, layout, navigation, app loader
      registry/              # App catalog, access control UI, fork/collab UI
  myApps/                    # Duong's public apps — available to everyone
    read-tracker/
      src/
      index.ts               # App manifest (metadata, routes, permissions)
    portfolio-tracker/
    task-list/
  yourApps/                  # Personal apps built for individual users
    bee/                     # Built for Duong's sister
      src/
      index.ts               # App manifest
  shared/                    # Shared utilities across apps
    ui/                      # Common UI components (if needed later)
    firebase/                # Firebase client init, helpers
    types/                   # Platform-wide TypeScript types
```

### App Manifest (`index.ts`)

Every app exports a manifest that the platform shell uses for registration:

```typescript
export interface AppManifest {
  id: string                    // Unique slug: "read-tracker", "bee"
  name: string                  // Display name
  description: string
  icon: string                  // Icon name or path
  category: 'myApps' | 'yourApps'
  version: string
  routes: RouteRecordRaw[]      // Vue Router routes for this app
  defaultSettings: {             // Defaults seeded into Firestore on first deploy
    collaboration: boolean
    forkable: boolean
    personalMode: boolean
  }
}
```

### Build Strategy

Single Vite build from `apps/platform/` that dynamically imports app modules. Each app under `myApps/` and `yourApps/` is a lazy-loaded route chunk. No separate deployments per app — one SPA, code-split per app.

This keeps deployment simple (one Firebase Hosting site) while still giving each app its own codebase boundary.

## Data Model

### Firestore Structure

**Platform-level collections** (root level):

```
/apps/{appId}                        # App registry
  name, description, icon, category, ownerId, version
  access: { public: bool, allowTryRequests: bool }
  settings: { collaboration: bool, forkable: bool, personalMode: bool }
  createdAt, updatedAt

/users/{userId}                      # User profiles
  displayName, email, photoURL
  role: 'admin' | 'collaborator' | 'user'   # Platform-wide role (default: 'user')
  notificationChannel: 'email' | 'discord'   # User's preferred notification method
  discordUserId?: string                      # Required if notificationChannel == 'discord'
  createdAt, lastLoginAt

/users/{userId}/appAccess/{appId}    # Which apps this user can access
  role: 'owner' | 'user' | 'collaborator' | 'fork-owner'
  grantedAt, grantedBy
  sourceAppId?                       # If this is a fork, the original app

/apps/{appId}/accessRequests/{requestId}   # "Can I try your app?" requests
  requesterId, status: 'pending' | 'approved' | 'denied'
  createdAt, respondedAt

/apps/{appId}/suggestions/{suggestionId}   # Collaboration suggestions
  authorId, title, description, status: 'open' | 'accepted' | 'rejected'
  createdAt

/forks/{forkId}                      # Fork registry
  sourceAppId, forkedByUserId, forkedAppId
  createdAt
```

**Per-app data** uses a namespaced subcollection pattern under a dedicated root:

```
/appData/{appId}/users/{userId}/{collection}/{docId}
```

Example for Read Tracker:
```
/appData/read-tracker/users/uid123/books/book1
/appData/read-tracker/users/uid123/readingSessions/session1
/appData/read-tracker/users/uid123/goals/goal1
```

Example for Bee:
```
/appData/bee/users/uid456/jobs/job1
/appData/bee/users/uid456/history/entry1
```

### Why This Structure (Not Separate Databases)

Firestore's free tier gives one database per project. Creating a database per app would require multiple Firebase projects or Spark-to-Blaze upgrade. The `/appData/{appId}/` prefix achieves logical isolation within one database:

- Security rules scope access per app
- Each app's code only reads/writes its own `/appData/{appId}/` subtree
- Migration path: if an app outgrows shared Firestore, move its subtree to a dedicated database (Blaze tier) with zero code change in the app — only the Firebase client init changes

### Migration from Current Schema

Current: `users/{userId}/readingSessions/`, `users/{userId}/books/`, etc.

Target: `appData/read-tracker/users/{userId}/readingSessions/`, etc.

Migration script moves documents from old paths to new paths. Can run incrementally. The app code switches to the new path helpers. Old paths can be tombstoned with a redirect document for safety.

## Access Model

### Roles (3 Tiers)

| Role | Scope | Can use apps | Can suggest improvements | Can fork | Can request new apps | Can manage all apps |
|------|-------|-------------|------------------------|----------|---------------------|---------------------|
| **admin** | Platform-wide | all apps | all apps | all forkable apps | n/a (creates apps directly) | yes |
| **collaborator** | Per-app + platform | granted apps + public | public apps + collab-enabled apps | forkable apps | unlimited requests | no |
| **user** (default) | Per-app | granted apps + public | no | no | 1 app request (for now) | no |

- **Admin** = Duong. Identified by a `role: 'admin'` field on his `/users/{userId}` document. Admin can view and manage all apps on the platform.
- **Collaborator** = trusted users who can improve public apps and other people's apps (if collaboration is enabled). Can request new apps freely with no limit.
- **User** = default role for new sign-ups. Can use public apps and any apps they've been granted access to. Can request only 1 app for now (enforced by counting their pending/approved requests).

### Per-App Owner Settings

Every app owner controls these settings on their app (via `/apps/{appId}.settings`):

| Setting | Default | Effect |
|---------|---------|--------|
| `collaboration` | false | When enabled, collaborators can suggest improvements to this app |
| `forkable` | false | When enabled, eligible users can fork this app |
| `personalMode` | false | When enabled, admin can only fix bugs — no feature changes. Owner controls feature direction. |

`personalMode` is an **operational constraint**, not a data access restriction. Admin retains full read/write access to app data for maintenance and bug fixing. What changes: when `personalMode` is on, admin commits to the app must be bug fixes only — no new features, no UX changes, no behavior modifications unless the owner requests them. This is enforced by convention and code review, not by security rules.

### Access Resolution

```
canAccess(userId, appId):
  user = /users/{userId}
  app = /apps/{appId}

  # Admin can access everything (personalMode doesn't restrict data access)
  if user.role == 'admin':
    return true

  # Public apps: any authenticated user
  if app.category == 'myApps' and app.access.public == true:
    return true

  # Check explicit access grant
  userAccess = /users/{userId}/appAccess/{appId}
  if userAccess exists and userAccess.role in ['owner', 'user', 'collaborator']:
    return true

  return false
```

### "Your Apps" Section

Every logged-in user sees a "Your Apps" section in the platform. This lists:
- Apps they own (created for them or forked)
- Apps they've been granted access to

Each owned app shows a settings panel where the owner can toggle `collaboration`, `forkable`, and `personalMode`.

### Request-to-Try Flow

1. User visits app catalog, sees a yourApp with `allowTryRequests: true`
2. User sends access request -> `/apps/{appId}/accessRequests/{requestId}`
3. **Rate limit**: users with role `user` can have at most 1 pending or approved request. Collaborators have no limit. Enforced in security rules via a count check or in app logic.
4. Owner receives notification via their preferred channel (email or Discord — see Notifications below)
5. Owner approves -> system writes `/users/{requesterId}/appAccess/{appId}` with role `user`

### Notifications

Users choose their notification channel in platform settings: **email** or **Discord**. Stored as `notificationChannel` on `/users/{userId}`.

- **Email**: Firebase Extensions (Trigger Email from Firestore) — write a doc to a `/mail` collection, the extension sends it. Free tier compatible.
- **Discord**: Post to the user via the existing Discord relay bot (`apps/discord-relay/`). Requires the user to link their Discord user ID in settings.

Notification triggers (all via Firestore-triggered Cloud Function or Extensions):
- Access request received (notify app owner)
- Access request approved/denied (notify requester)
- New suggestion on a collaborative app (notify app owner)

Implementation note: a single Cloud Function watches `/notifications/{notifId}` (a write-ahead queue). Each notification doc specifies `recipientId`, `type`, and `payload`. The function reads the recipient's `notificationChannel` and dispatches accordingly.

### Forking

1. User visits a forkable app in the catalog
2. Clicks "Fork" -> system creates:
   - New `/apps/{forkedAppId}` doc (category: `yourApps`, ownerId: forker)
   - `/forks/{forkId}` linking source to fork
   - `/users/{forkerId}/appAccess/{forkedAppId}` with role `fork-owner`
3. Fork gets its own `/appData/{forkedAppId}/` subtree — starts empty (no data copy)
4. Fork uses the same codebase (same app module) but different appId for data isolation

Note: forking creates data isolation, not code divergence. All forks of "Read Tracker" run the same Read Tracker code. This is "fork the instance" not "fork the repo."

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: is the caller an admin?
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // App registry: anyone authed can read; admin can write; owners can update their own app's settings
    match /apps/{appId} {
      allow read: if request.auth != null;
      allow create, delete: if isAdmin();
      allow update: if isAdmin()
        || request.auth.uid == resource.data.ownerId;
    }

    // User profiles: own profile; admin can read all
    match /users/{userId} {
      allow read: if request.auth.uid == userId || isAdmin();
      allow write: if request.auth.uid == userId;
      // role field is admin-writable only (enforce via a validate rule or Cloud Function)

      match /appAccess/{appId} {
        allow read: if request.auth.uid == userId || isAdmin();
        allow write: if isAdmin()
          || request.auth.uid == get(/databases/$(database)/documents/apps/$(appId)).data.ownerId;
      }
    }

    // App data: user's own data within an app they can access
    match /appData/{appId}/users/{userId}/{collection}/{docId} {
      allow read, write: if request.auth.uid == userId && (
        // User has explicit access
        exists(/databases/$(database)/documents/users/$(request.auth.uid)/appAccess/$(appId))
        // OR the app is public
        || get(/databases/$(database)/documents/apps/$(appId)).data.access.public == true
      );
      // Admin can read/write all app data (for maintenance and bug fixes)
      allow read, write: if isAdmin();
    }

    // Access requests
    match /apps/{appId}/accessRequests/{requestId} {
      allow create: if request.auth != null;
      allow read, update: if isAdmin()
        || request.auth.uid == get(/databases/$(database)/documents/apps/$(appId)).data.ownerId;
    }

    // Suggestions (collaboration)
    match /apps/{appId}/suggestions/{suggestionId} {
      allow create: if request.auth != null
        && get(/databases/$(database)/documents/apps/$(appId)).data.settings.collaboration == true;
      allow read: if request.auth != null;
    }
  }
}
```

## Auth

Keep Firebase Auth as-is. No changes needed. The platform shell handles sign-in/sign-up. Individual apps receive the authenticated user context from the platform.

**Admin identity**: Duong's Google account gets `role: 'admin'` in his `/users/{userId}` Firestore document. This is checked in security rules via the `isAdmin()` helper function. No custom claims or Cloud Functions needed — the role lives in Firestore alongside the user profile. Seeded manually (or via a one-time script) when the platform is first deployed.

## Firebase Helper Layer

Replace the current `firestore.ts` (which hardcodes collection paths) with an app-scoped helper:

```typescript
// shared/firebase/appFirestore.ts
export function appCollection(appId: string, userId: string, collectionName: string) {
  return collection(db, `appData/${appId}/users/${userId}/${collectionName}`)
}

export function appDoc(appId: string, userId: string, collectionName: string, docId: string) {
  return doc(db, `appData/${appId}/users/${userId}/${collectionName}/${docId}`)
}
```

Each app imports these helpers instead of constructing paths directly. The appId comes from the app manifest, injected via Vue's `provide/inject` or a composable.

## Implementation Phases

### Phase 1: Restructure (no user-facing changes)

1. Create monorepo structure (`apps/platform/`, `apps/myApps/`, `apps/yourApps/`, `apps/shared/`)
2. Move existing app code from `apps/myapps/src/views/ReadTracker/` etc. into `apps/myApps/read-tracker/` etc.
3. Create app manifest files for each existing app
4. Build platform shell with app loader
5. Replace hardcoded Firestore paths with `appCollection`/`appDoc` helpers
6. Deploy security rules
7. Run data migration script (old paths -> `/appData/{appId}/` paths)
8. Move Bee from `apps/myapps/src/views/bee/` to `apps/yourApps/bee/`

### Phase 2: App Registry and Access Control

1. Build `/apps/{appId}` registry (seed from manifests)
2. Build app catalog UI (the "store" view showing available apps)
3. Implement access checking in router guard
4. Build request-to-try flow (request, notification, approve/deny)
5. Add user profile page showing "my apps"

### Phase 3: Collaboration and Forking

1. Build suggestion/feedback UI for collaborative apps
2. Build fork flow (create fork entry, new appData subtree)
3. Add fork badge/attribution in UI ("forked from X")

## Cost Considerations

All of this runs on Firebase Spark (free) tier:
- 1 GiB Firestore storage, 50K reads/day, 20K writes/day — more than sufficient for a personal platform with <100 users
- Firebase Hosting: 10 GB/month transfer — fine for an SPA
- Firebase Auth: free for email/password and Google sign-in
- No Cloud Functions required for core access control flow (security rules handle it). One Cloud Function needed for notification dispatch (email + Discord). Firebase Extensions "Trigger Email" is free on Spark plan.

## Resolved Questions

1. **Admin identity**: Duong's Google account gets `role: 'admin'` in Firestore. Checked in security rules. No custom claims needed.

2. **Fork semantics**: Instance-level forks confirmed (same code, separate data).

3. **Roles**: Three-tier model (admin / collaborator / user). Users limited to 1 app request; collaborators unlimited.

4. **Notifications**: Per-user choice of email or Discord. Dispatched via a Cloud Function watching a `/notifications` queue.

5. **URL structure**: Category-prefixed routes on `apps.darkstrawberry.com` (Duong's decision).

### URL Structure

Domain: `apps.darkstrawberry.com`

```
/myApps/{app-slug}/...           # Public apps
/myApps/read-tracker/dashboard
/myApps/portfolio-tracker/transactions
/myApps/task-list/dashboard

/yourApps/{app-slug}/...         # Personal apps
/yourApps/bee/home
```

Platform pages use top-level routes:

```
/                        # Landing / app catalog
/settings                # User settings (notification prefs, profile)
/your-apps               # "Your Apps" section (owned + granted)
```

This mirrors the monorepo structure (`apps/myApps/`, `apps/yourApps/`) directly into the URL, making the category visible in every URL. No namespace collision risk since all app routes are scoped under their category prefix.

Migration from current `/read-tracker` etc. is a one-time router change. Add redirects from old paths for bookmarked URLs.

## All Questions Resolved

No open questions remain. This plan is ready for review and approval.
