#!/usr/bin/env bash
# Scaffold a new standalone DS app from template.
# Usage: bash scripts/scaffold-app.sh <category> <slug> <title>
# Example: bash scripts/scaffold-app.sh myApps my-new-app "My New App"
set -euo pipefail

CATEGORY="${1:-}"
SLUG="${2:-}"
TITLE="${3:-}"

if [ -z "$CATEGORY" ] || [ -z "$SLUG" ] || [ -z "$TITLE" ]; then
  echo "Usage: bash scripts/scaffold-app.sh <category> <slug> <title>"
  echo "  category: myApps or yourApps"
  echo "  slug:     url-safe slug (e.g. my-new-app)"
  echo "  title:    human-readable title (e.g. 'My New App')"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/$CATEGORY/$SLUG"
BASE_PATH="/$CATEGORY/$SLUG/"
PKG_NAME="@ds/$SLUG"

if [ -d "$APP_DIR" ]; then
  echo "ERROR: $APP_DIR already exists" >&2
  exit 1
fi

TEMPLATE_DIR="$ROOT_DIR/apps/myapps/read-tracker"
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "ERROR: Template dir not found: $TEMPLATE_DIR" >&2
  exit 1
fi

echo "Scaffolding $TITLE at $APP_DIR..."
mkdir -p "$APP_DIR/src"

# Copy template skeleton (no app-specific views)
for f in package.json vite.config.ts tsconfig.json tsconfig.node.json tailwind.config.js postcss.config.js index.html; do
  [ -f "$TEMPLATE_DIR/$f" ] && cp "$TEMPLATE_DIR/$f" "$APP_DIR/$f"
done
for d in src/firebase src/stores src/components src/i18n src/assets; do
  [ -d "$TEMPLATE_DIR/$d" ] && cp -r "$TEMPLATE_DIR/$d" "$APP_DIR/$d"
done
cp "$TEMPLATE_DIR/src/App.vue" "$APP_DIR/src/App.vue"
cp "$TEMPLATE_DIR/src/vite-env.d.ts" "$APP_DIR/src/vite-env.d.ts"
[ -d "$TEMPLATE_DIR/public" ] && cp -r "$TEMPLATE_DIR/public" "$APP_DIR/public"

# Patch package.json name
if command -v sed >/dev/null 2>&1; then
  sed -i.bak "s|@ds/read-tracker|$PKG_NAME|g" "$APP_DIR/package.json" && rm -f "$APP_DIR/package.json.bak"
fi

# Patch vite.config.ts base
if command -v sed >/dev/null 2>&1; then
  sed -i.bak "s|base: '/myApps/read-tracker/'|base: '$BASE_PATH'|g" "$APP_DIR/vite.config.ts" && rm -f "$APP_DIR/vite.config.ts.bak"
fi

# Write stub main.ts
cat > "$APP_DIR/src/main.ts" << EOF
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { createI18n } from 'vue-i18n'
import router from './router'
import App from './App.vue'
import './assets/main.css'

const pinia = createPinia()
const i18n = createI18n({ legacy: false, locale: 'en' })

createApp(App)
  .use(pinia)
  .use(router)
  .use(i18n)
  .mount('#app')
EOF

# Write stub router
mkdir -p "$APP_DIR/src/router"
cat > "$APP_DIR/src/router/index.ts" << EOF
import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHistory('$BASE_PATH'),
  routes: [
    {
      path: '/',
      component: () => import('../views/HomeView.vue'),
      meta: { requiresAuth: true },
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.init()
  if (to.meta.requiresAuth && !auth.user) return '/'
})

export default router
EOF

# Write stub view
mkdir -p "$APP_DIR/src/views"
cat > "$APP_DIR/src/views/HomeView.vue" << EOF
<template>
  <div class="p-8">
    <h1 class="text-2xl font-bold">$TITLE</h1>
    <p class="text-gray-500 mt-2">Scaffold created. Replace this view.</p>
  </div>
</template>
EOF

echo ""
echo "Done! App scaffolded at: $APP_DIR"
echo ""
echo "Next steps:"
echo "  1. Add to root firebase.json rewrites:"
echo "     { \"source\": \"$BASE_PATH**\", \"destination\": \"${BASE_PATH}index.html\" }"
echo "  2. cd $APP_DIR && npm install && npm run build"
echo "  3. git add and commit"
