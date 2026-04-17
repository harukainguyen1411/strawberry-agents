# Turbo Cache is Blind to Env Vars by Default

**Date:** 2026-04-13
**Context:** Production incident — blank page on apps.darkstrawberry.com

Turborepo does not include environment variables or `.env*` file contents in its cache hash by default. A build produced without required `VITE_FIREBASE_*` vars will be cached and reused by subsequent builds that do have the vars set, because Turbo sees identical source files and considers it a cache hit.

**Fix:** Use `env` and `dotEnv` fields in `turbo.json` pipeline config to explicitly list env vars and dotenv files that affect the build output. This makes Turbo invalidate the cache when env state changes.

**Broader lesson:** Any build cache system that doesn't hash runtime configuration inputs is a latent incident. Always verify what your cache key actually covers.
