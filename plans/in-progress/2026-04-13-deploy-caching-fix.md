---
status: in-progress
owner: swain
---

# Deploy Caching Fix — Firebase Hosting Cache-Control Headers

## Summary

After deploying a new version of Dark Strawberry (landing + portal), browsers that previously visited the site serve stale content from cache for up to 1 hour. The fix: set `Cache-Control: no-cache` on HTML files so browsers always revalidate, while keeping long-lived caching on hashed assets.

## Root Cause

`firebase.json` defines `Cache-Control: max-age=31536000` for `**/*.@(js|css)` and image assets, but has **no explicit Cache-Control header for HTML files**. Firebase Hosting's default for unmatched files is `cache-control: max-age=3600` (1 hour). This means:

- `index.html` (the SPA entry point for every route) is cached by browsers for 1 hour
- After a deploy, Firebase CDN serves the new `index.html` immediately, but browsers with a cached copy never ask for it until the 1h TTL expires
- The HTML references hashed JS/CSS chunks (`assets/index-abc123.js`), so stale HTML points to old chunk filenames that may no longer exist on the server — causing broken pages, not just old content

No service worker is present. Vite's default build already produces content-hashed asset filenames (good). The only issue is the HTML caching policy.

## Fix

Add a `Cache-Control: no-cache` header for `index.html` and any other HTML files. `no-cache` does NOT mean "don't cache" — it means "always revalidate with the server before using the cached copy." This gives instant updates after deploy while still allowing conditional requests (304 Not Modified) for efficiency.

## Implementation Steps

### Step 1: Update `firebase.json` headers

Add a new header rule **before** the catch-all `**` rule. The final `headers` array should be:

```json
"headers": [
  {
    "source": "**/*.html",
    "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
  },
  {
    "source": "**/*.@(js|css)",
    "headers": [{ "key": "Cache-Control", "value": "max-age=31536000, immutable" }]
  },
  {
    "source": "**/*.@(jpg|jpeg|gif|png|svg|webp|ico)",
    "headers": [{ "key": "Cache-Control", "value": "max-age=31536000, immutable" }]
  },
  {
    "source": "**",
    "headers": [
      { "key": "X-Content-Type-Options", "value": "nosniff" },
      { "key": "X-Frame-Options", "value": "DENY" }
    ]
  }
]
```

Key changes:
1. New `**/*.html` rule with `no-cache` — placed first so it matches before the catch-all
2. Added `immutable` to JS/CSS and image rules — tells browsers these hashed files never change, eliminating conditional revalidation requests entirely

### Step 2: Deploy

```bash
npm run build          # rebuild all apps (turborepo)
bash scripts/composite-deploy.sh   # assemble deploy/
npx firebase-tools deploy --only hosting --project myapps-b31ea
```

### Step 3: Verify

After deploy, run these curl commands to confirm headers:

```bash
# HTML should show: cache-control: no-cache
curl -sI https://darkstrawberry.com/ | grep -i cache-control

# JS asset should show: cache-control: max-age=31536000, immutable
# (pick any .js file from the page source)
curl -sI https://darkstrawberry.com/assets/index-*.js | grep -i cache-control
```

Expected output:
```
cache-control: no-cache                          # for HTML
cache-control: max-age=31536000, immutable       # for JS/CSS
```

Also verify in a browser: open DevTools Network tab, load the site, check `index.html` response headers show `no-cache`.

## Notes

- Firebase Hosting CDN also respects these headers for edge caching. Setting `no-cache` on HTML means the CDN will revalidate with the origin on every request, ensuring deploys propagate immediately.
- The `immutable` directive on hashed assets is safe because Vite always generates new filenames when content changes. Old filenames are never reused.
- No changes needed to `composite-deploy.sh` or Vite config — the issue is purely in Firebase Hosting header configuration.
