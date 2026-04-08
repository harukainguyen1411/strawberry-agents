---
status: proposed
owner: swain
gdoc_id: 1Ddm-1z_s1Suuhbh0eLyYAGSGc0wCrQFRyuNg-_DZhr4
gdoc_url: https://docs.google.com/document/d/1Ddm-1z_s1Suuhbh0eLyYAGSGc0wCrQFRyuNg-_DZhr4/edit
---

# Plan Viewer — Mobile Markdown Reader for Strawberry

## Goal

Let Duong browse, read, and approve plan files from the strawberry repo on his phone. A new section within the existing myapps Vue app — not a separate app.

## Why Not GitHub Mobile?

GitHub mobile renders markdown but has no concept of plan status, no approval action, and navigating nested directories is clunky. A dedicated viewer gives: clean mobile-first UI, status-aware browsing (proposed/approved/in-progress), and one-tap approval.

## Architecture

```
Duong's phone (myapps)
    ↓ GitHub Contents API (GET /repos/:owner/:repo/contents/:path)
    ↓ Auth: Firebase-stored GitHub PAT (encrypted at rest)
GitHub API → returns file list + base64 content
    ↓ marked.js (already installed in myapps)
Rendered markdown on mobile screen
    ↓ Approval action: GitHub API (PUT) moves file between directories
```

### Data Flow

1. **Browse**: `GET /repos/Duongntd/strawberry/contents/plans/{status}/` → file list
2. **Read**: `GET /repos/Duongntd/strawberry/contents/plans/{status}/{filename}` → base64 content → decode → render with `marked`
3. **Approve** (optional): Create commit via GitHub API that moves file from `plans/proposed/` to `plans/approved/`

### Authentication

The repo is private. Options considered:

| Option | Pros | Cons |
|--------|------|------|
| **GitHub PAT stored in Firestore** | Simple, works now | Token rotation manual, broad scope |
| **GitHub OAuth app** | Proper OAuth flow, granular | Complex setup, overkill for single user |
| **Firebase Function proxy** | Hides token from client | Adds infra (Functions billing) |

**Recommendation: GitHub PAT in Firestore** — Duong is the only user. Store a fine-grained PAT (repo contents read/write scope on `strawberry` only) in a Firestore document under his user profile. The app reads it on auth. If the token leaks, it's scoped to one repo and easily revoked.

## Implementation

### New Files

```
src/
├── views/PlanViewer/
│   ├── Browser.vue          # Directory listing with status tabs
│   └── Reader.vue           # Single file markdown view + approve button
├── stores/
│   └── planViewer.ts        # GitHub API calls, caching, state
├── components/PlanViewer/
│   └── PlanCard.vue         # File card in browser list (name, date, status badge)
```

### Routes

```ts
{
  path: '/plan-viewer',
  children: [
    { path: '', redirect: '/plan-viewer/proposed' },
    { path: ':status', component: Browser },      // proposed, approved, in-progress, implemented
    { path: ':status/:filename', component: Reader }
  ]
}
```

### Browser View (`Browser.vue`)

- **Tab bar** at top: Proposed | Approved | In Progress | Implemented
- Each tab fetches `plans/{status}/` from GitHub Contents API
- File list shows: filename (cleaned slug), date extracted from filename, YAML frontmatter owner
- Tap → navigates to Reader
- Pull-to-refresh to re-fetch
- Cache in Pinia store (5-minute TTL) to avoid rate limits

### Reader View (`Reader.vue`)

- Fetches file content (base64 → decode → parse)
- Strips YAML frontmatter, displays it as metadata chips (status, owner)
- Renders markdown body via `marked` with existing `.markdown-content` styles
- Mobile-optimized: full-width, comfortable font size, code blocks scroll horizontally
- **Approve button** (only on `proposed` files): moves file to `plans/approved/`, updates frontmatter `status: approved`, commits via GitHub API
- Back button returns to browser

### GitHub API Layer (`stores/planViewer.ts`)

```ts
// Core API calls
listFiles(status: string): Promise<FileEntry[]>
getFileContent(status: string, filename: string): Promise<{ content: string, sha: string }>
approveFile(filename: string, currentSha: string): Promise<void>  // move proposed → approved
```

- Uses `fetch` directly (no octokit needed — 3 endpoints)
- PAT read from Firestore on auth (`users/{uid}/secrets/github`)
- Rate limit: GitHub allows 5000 req/hr with PAT — more than enough
- Error handling: 404 (file moved/deleted), 401 (token expired), network errors

### Approve Flow (GitHub API)

Moving a file in Git requires two API calls:
1. **Create file** at `plans/approved/{filename}` with updated frontmatter (`status: approved`) — `PUT /repos/:owner/:repo/contents/:path`
2. **Delete file** at `plans/proposed/{filename}` — `DELETE /repos/:owner/:repo/contents/:path`

Commit message: `chore: approve plan {filename}`

Alternative: Use the Git Trees API for atomic move (single commit). More complex but cleaner history. Recommend starting with the two-call approach — it works and is simpler.

### Home Card

Add a "Plan Viewer" card to the myapps home screen, consistent with existing Read Tracker / Portfolio / Task List cards. Shows count of proposed plans as a badge.

## Mobile UX Considerations

- Tabs are swipeable (touch-friendly, no tiny links)
- File list uses large tap targets (full-width cards, not text links)
- Markdown rendering uses `prose` Tailwind class or equivalent for comfortable reading
- Code blocks have horizontal scroll, not wrap
- Approve button is prominent (green, bottom-fixed) with confirmation dialog
- Loading states with skeleton placeholders

## Security

- GitHub PAT stored in Firestore under authenticated user doc — only Duong can read
- Fine-grained PAT scoped to `strawberry` repo only, `contents: read+write`
- No PAT in source code, env vars, or localStorage
- Firestore rules: `match /users/{uid}/secrets/{doc} { allow read: if request.auth.uid == uid; }`

## What This Does NOT Include

- Editing/creating plan files (use Cursor or CLI for that)
- Viewing non-plan files (architecture/, agents/, etc.) — could extend later
- Offline support (needs network for GitHub API)
- Real-time updates (pull-to-refresh is fine for plan review cadence)

## Dependencies

- `marked` — already installed
- No new packages needed

## Setup Required from Duong

1. Create a fine-grained GitHub PAT at github.com/settings/personal-access-tokens
   - Scope: `strawberry` repo only
   - Permissions: Contents (read + write)
2. Store it in Firestore: `users/{uid}/secrets/github` → `{ pat: "github_pat_..." }`
3. Add Firestore security rule for the secrets subcollection

## Estimated Scope

- ~4-5 files, ~400-500 lines of new code
- Leverages existing: marked, auth, router patterns, Tailwind, Firebase
- No new infra or services
