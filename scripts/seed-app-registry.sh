#!/usr/bin/env bash
# seed-app-registry.sh
#
# Seeds Firestore /apps/{appId} documents from the app manifests.
# Only creates entries that don't already exist (safe to re-run).
#
# Prerequisites:
#   - Node.js 18+
#   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account key
#   - FIREBASE_PROJECT_ID env var
#   - ADMIN_UID env var (Duong's Firebase Auth UID)
#
# Usage:
#   FIREBASE_PROJECT_ID=myapps-b31ea ADMIN_UID=<uid> GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json ./scripts/seed-app-registry.sh

set -euo pipefail

if [ -z "${FIREBASE_PROJECT_ID:-}" ]; then
  echo "Error: FIREBASE_PROJECT_ID is required" >&2
  exit 1
fi

if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  echo "Error: GOOGLE_APPLICATION_CREDENTIALS is required" >&2
  exit 1
fi

if [ -z "${ADMIN_UID:-}" ]; then
  echo "Error: ADMIN_UID is required (Duong's Firebase Auth UID)" >&2
  exit 1
fi

node --input-type=module <<'SCRIPT'
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const adminUid = process.env.ADMIN_UID;

initializeApp({
  credential: cert(process.env.GOOGLE_APPLICATION_CREDENTIALS),
  projectId: process.env.FIREBASE_PROJECT_ID,
});
const db = getFirestore();

const APPS = [
  {
    id: "read-tracker",
    name: "Read Tracker",
    description: "Track your reading sessions, books, and goals.",
    icon: "\u{1F4DA}",
    category: "myApps",
    version: "1.0.0",
    settings: { collaboration: false, forkable: false, personalMode: false },
  },
  {
    id: "portfolio-tracker",
    name: "Portfolio Tracker",
    description: "Track your investment portfolio and transactions.",
    icon: "\u{1F4C8}",
    category: "myApps",
    version: "1.0.0",
    settings: { collaboration: false, forkable: false, personalMode: false },
  },
  {
    id: "task-list",
    name: "Task List",
    description: "Manage your tasks and to-dos.",
    icon: "\u{1F4CB}",
    category: "myApps",
    version: "1.0.0",
    settings: { collaboration: false, forkable: false, personalMode: false },
  },
  {
    id: "bee",
    name: "Bee",
    description: "AI-powered document processing assistant.",
    icon: "\u{1F41D}",
    category: "yourApps",
    version: "1.0.0",
    settings: { collaboration: false, forkable: false, personalMode: true },
  },
];

async function main() {
  let created = 0;
  let skipped = 0;

  for (const app of APPS) {
    const ref = db.collection("apps").doc(app.id);
    const existing = await ref.get();

    if (existing.exists) {
      console.log(`SKIP ${app.id} (already exists)`);
      skipped++;
      continue;
    }

    const isPublic = app.category === "myApps";

    await ref.set({
      name: app.name,
      description: app.description,
      icon: app.icon,
      category: app.category,
      version: app.version,
      ownerId: app.category === "yourApps" ? null : adminUid,
      access: {
        public: isPublic,
        allowTryRequests: !isPublic,
      },
      settings: app.settings,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    console.log(`CREATED ${app.id}`);
    created++;
  }

  console.log(`\nDone. Created ${created}, skipped ${skipped}.`);
}

main().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
SCRIPT
