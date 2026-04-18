#!/usr/bin/env bash
# migrate-firestore-paths.sh
#
# Migrates Firestore documents from the old flat schema:
#   /users/{userId}/{collection}/{docId}
# to the new app-namespaced schema:
#   /appData/{appId}/users/{userId}/{collection}/{docId}
#
# Mapping:
#   readingSessions, books, goals       -> appData/read-tracker/users/{uid}/...
#   stockHoldings, transactions, portfolioAccount -> appData/portfolio-tracker/users/{uid}/...
#   tasks                               -> appData/task-list/users/{uid}/...
#
# Prerequisites:
#   - Node.js 18+
#   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account key
#   - FIREBASE_PROJECT_ID env var
#
# Usage:
#   FIREBASE_PROJECT_ID=myapps-b31ea GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json ./scripts/migrate-firestore-paths.sh [--dry-run]
#
# With --dry-run, the script prints what it would do without writing anything.

set -euo pipefail

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN="true"
  echo "[DRY RUN] No writes will be performed."
fi

if [ -z "${FIREBASE_PROJECT_ID:-}" ]; then
  echo "Error: FIREBASE_PROJECT_ID is required" >&2
  exit 1
fi

if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  echo "Error: GOOGLE_APPLICATION_CREDENTIALS is required" >&2
  exit 1
fi

if [ ! -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
  echo "Error: GOOGLE_APPLICATION_CREDENTIALS file not found: ${GOOGLE_APPLICATION_CREDENTIALS}" >&2
  exit 1
fi

# Use an inline Node.js script for the migration
node --input-type=module <<'SCRIPT'
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const dryRun = process.env.DRY_RUN === "true";

initializeApp({
  credential: cert(process.env.GOOGLE_APPLICATION_CREDENTIALS),
  projectId: process.env.FIREBASE_PROJECT_ID,
});
const db = getFirestore();

// App ID -> collection names that belong to it
const APP_COLLECTIONS = {
  "read-tracker": ["readingSessions", "books", "goals"],
  "portfolio-tracker": ["stockHoldings", "transactions", "portfolioAccount"],
  "task-list": ["tasks"],
};

async function migrateCollection(userId, collectionName, appId) {
  const oldPath = `users/${userId}/${collectionName}`;
  const newPath = `appData/${appId}/users/${userId}/${collectionName}`;

  const oldRef = db.collection(oldPath);
  const snapshot = await oldRef.get();

  if (snapshot.empty) return 0;

  let count = 0;
  const batch = db.batch();

  for (const doc of snapshot.docs) {
    const newDocRef = db.collection(newPath).doc(doc.id);

    // Check if already migrated
    const existing = await newDocRef.get();
    if (existing.exists) {
      console.log(`  SKIP ${newPath}/${doc.id} (already exists)`);
      continue;
    }

    if (dryRun) {
      console.log(`  WOULD COPY ${oldPath}/${doc.id} -> ${newPath}/${doc.id}`);
    } else {
      batch.set(newDocRef, doc.data());
      console.log(`  COPY ${oldPath}/${doc.id} -> ${newPath}/${doc.id}`);
    }
    count++;
  }

  if (!dryRun && count > 0) {
    await batch.commit();
  }

  return count;
}

async function main() {
  // Get all users
  const usersSnapshot = await db.collection("users").get();
  const userIds = usersSnapshot.docs.map((d) => d.id);

  console.log(`Found ${userIds.length} user(s) to migrate.`);

  let totalMigrated = 0;

  for (const userId of userIds) {
    console.log(`\nMigrating user: ${userId}`);

    for (const [appId, collections] of Object.entries(APP_COLLECTIONS)) {
      for (const collectionName of collections) {
        const count = await migrateCollection(userId, collectionName, appId);
        totalMigrated += count;
      }
    }
  }

  console.log(`\nDone. ${dryRun ? "Would migrate" : "Migrated"} ${totalMigrated} document(s).`);
}

main().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
SCRIPT
