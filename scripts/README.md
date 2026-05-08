# Algolia Backfill Scripts

One-time scripts to backfill existing Firestore data into Algolia
via the `firestore-algolia-search` extensions.

## Why?

The Firebase extension only syncs documents that are **created or
updated AFTER** the extension is installed. Existing documents stay
out of Algolia until they're re-saved. This script re-saves every
document so the extension picks them up.

## Setup (run once)

1. **Download Firebase service account key**
   - Firebase Console → Project Settings (gear icon) → **Service accounts** tab
   - Click **Generate new private key** → confirm
   - Save the downloaded JSON as `service-account-key.json` in this folder
   - ⚠️ **Never commit this file** — it has full admin access to your project. (`.gitignore` already excludes it.)

2. **Install Node.js** (if not already)
   - https://nodejs.org → install the LTS version

3. **Install dependencies**
   ```powershell
   cd "C:\Users\user\OneDrive\Desktop\teman_app\flutter_TEMAN\scripts"
   npm install
   ```

## Run

```powershell
npm run backfill
```

The script iterates these top-level collections:
- `posts`
- `meetups`
- `questions`
- `jobs`
- `marketplace`

For each document it issues a no-op `set(..., { merge: true })`
write — same data, same fields — so the document content does NOT
change but the `firestore-algolia-search` extension's onWrite
trigger fires and copies the document to its Algolia index.

## After it finishes

1. Open Algolia Dashboard → Search → each index
2. Verify the record count matches the Firestore document count
3. Allow 1–5 minutes for the Cloud Functions to drain the queue

## Troubleshooting

- **"Could not load service-account-key.json"** → did you download
  the key and save it as `service-account-key.json` in this folder?
- **Permission denied on writes** → service account needs Firestore
  write permission. The default "Firebase Admin SDK" key has it.
- **Algolia indices still empty after backfill** → check each
  extension instance in Firebase Console → Extensions → click the
  instance → "Logs" tab for errors.
