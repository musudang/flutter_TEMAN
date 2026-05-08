// One-time backfill script.
//
// Re-saves every document in the indexed top-level collections so that
// the `firestore-algolia-search` extension instances re-index them into
// Algolia. The script does NOT mutate document content — it issues a
// no-op `set(..., { merge: true })` write so that the extension's
// onWrite trigger fires.
//
// Usage:
//   1. Download Firebase service account JSON
//      (Firebase Console → Project Settings → Service accounts →
//       Generate new private key) and save it as
//      `service-account-key.json` next to this file.
//   2. From this folder run:
//        npm install
//        npm run backfill

const admin = require('firebase-admin');
const path = require('path');

const KEY_PATH = path.join(__dirname, 'service-account-key.json');

let serviceAccount;
try {
  serviceAccount = require(KEY_PATH);
} catch (e) {
  console.error(
    '\n✗ Could not load service-account-key.json.\n' +
      '  Download it from Firebase Console → Project Settings →\n' +
      '  Service accounts → Generate new private key, then save it as:\n' +
      '    ' +
      KEY_PATH +
      '\n',
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Top-level collections that have a `firestore-algolia-search`
// extension instance configured.
const COLLECTIONS = ['posts', 'meetups', 'questions', 'jobs', 'marketplace'];

// Throttle between writes (ms). Raise if you hit Algolia rate limits.
const WRITE_DELAY_MS = 100;

const sleep = (ms) => new Promise((res) => setTimeout(res, ms));

async function backfillCollection(collectionName) {
  console.log(`\n▶ Backfilling "${collectionName}"...`);
  const snapshot = await db.collection(collectionName).get();
  console.log(`  Found ${snapshot.size} document(s)`);

  if (snapshot.empty) {
    console.log('  (nothing to backfill)');
    return;
  }

  let done = 0;
  let errors = 0;
  for (const doc of snapshot.docs) {
    try {
      // Re-save with the SAME data. This still triggers the extension's
      // onWrite handler → the extension copies the doc to Algolia.
      await doc.ref.set(doc.data(), { merge: true });
      done++;
    } catch (e) {
      errors++;
      console.error(`  ✗ ${doc.id}: ${e.message}`);
    }
    if (done % 10 === 0 && done > 0) {
      process.stdout.write(`  ${done}/${snapshot.size}\r`);
    }
    if (WRITE_DELAY_MS > 0) await sleep(WRITE_DELAY_MS);
  }
  console.log(`  ✓ ${collectionName}: ${done} re-saved, ${errors} failed`);
}

(async () => {
  console.log('Algolia backfill starting…');
  console.log(`Project: ${serviceAccount.project_id}`);
  console.log(`Collections: ${COLLECTIONS.join(', ')}`);

  for (const collection of COLLECTIONS) {
    try {
      await backfillCollection(collection);
    } catch (e) {
      console.error(`\n✗ Failed on "${collection}":`, e.message);
    }
  }

  console.log('\n✅ Backfill complete.');
  console.log(
    'Check Algolia Dashboard → Search → each index. Record counts ' +
      'should match Firestore within 1–5 minutes.',
  );

  process.exit(0);
})().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
