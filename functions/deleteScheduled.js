/**
 * Scheduled hard-delete worker for DPDP self-service deletion requests.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DRAFT — NOT DEPLOYED. Review together with PROJECT_AUDIT.md, CREDENTIALS.md
 * and firestore.rules.proposed before any deployment. This file is wired into
 * functions/index.js for local review only.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * For every deletion_requests/{tokenId} whose executeAfter has passed this job:
 *   1. reads the consent metadata needed for the tombstone,
 *   2. deletes the token document, its `children` + `documents` subcollections,
 *   3. deletes every Storage object under `tokens/{tokenId}/`,
 *   4. deletes every mirrored Drive file recorded in `drive_mirror/{tokenId}_*`
 *      and removes the mapping rows,
 *   5. deletes the consent record after extracting its metadata,
 *   6. writes `deleted_tokens/{tokenId}` with ONLY:
 *        tokenId, deletedAt, consentGivenAt, consentVersion, withdrawnAt
 *      — no name, phone, Aadhaar or document data,
 *   7. marks the request executed and logs counts (tokenId only, never PII).
 *
 * KNOWN GAP (reported to the owner): files mirrored before drive_mirror
 * mapping was introduced have no driveFileId row, so they cannot be deleted
 * automatically. A one-off backfill/reconciliation job is required: list the
 * `Token_<id>` Drive folder and delete leftover files, or re-sync each token.
 * This job logs a warning for each token with Storage/Drive mismatch.
 *
 * Secrets are read via defineSecret — never hardcoded. Reuse the same Secret
 * Manager entries as the mirror function (see CREDENTIALS.md).
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const { defineSecret } = require("firebase-functions/params");

// Same Secret Manager names as functions/index.js.
const GOOGLE_OAUTH_CLIENT_ID = defineSecret("GOOGLE_OAUTH_CLIENT_ID");
const GOOGLE_OAUTH_CLIENT_SECRET = defineSecret("GOOGLE_OAUTH_CLIENT_SECRET");
const GOOGLE_DRIVE_REFRESH_TOKEN = defineSecret("GOOGLE_DRIVE_REFRESH_TOKEN");

const DELETION_REQUESTS = "deletion_requests";
const DELETED_TOKENS = "deleted_tokens";
const TOKENS = "tokens";
const CONSENT_RECORDS = "consent_records";
const DRIVE_MIRROR = "drive_mirror";

// Fields permitted in the tombstone. Anything else is a bug — see
// DeletionRules.tombstoneFieldWhitelist on the Dart side.
const TOMBSTONE_FIELDS = [
  "tokenId",
  "deletedAt",
  "consentGivenAt",
  "consentVersion",
  "withdrawnAt",
];

exports.deleteScheduled = functions
  .runWith({
    memory: "512MB",
    timeoutSeconds: 540,
    secrets: [
      GOOGLE_OAUTH_CLIENT_ID,
      GOOGLE_OAUTH_CLIENT_SECRET,
      GOOGLE_DRIVE_REFRESH_TOKEN,
    ],
  })
  .pubsub.schedule("every 1 hours")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    const oauth2Client = new google.auth.OAuth2(
      GOOGLE_OAUTH_CLIENT_ID.value(),
      GOOGLE_OAUTH_CLIENT_SECRET.value(),
      "https://developers.google.com/oauthplayground"
    );
    oauth2Client.setCredentials({
      refresh_token: GOOGLE_DRIVE_REFRESH_TOKEN.value(),
    });
    const drive = google.drive({ version: "v3", auth: oauth2Client });

    const now = admin.firestore.Timestamp.now();
    const expired = await db
      .collection(DELETION_REQUESTS)
      .where("status", "==", "pending")
      .where("executeAfter", "<=", now)
      .get();

    console.log(
      `deleteScheduled: ${expired.size} request(s) eligible for hard delete`
    );

    let processed = 0;
    for (const requestDoc of expired.docs) {
      const tokenId = requestDoc.id;
      try {
        await processDeletion({ db, bucket, drive, tokenId, requestDoc });
        processed += 1;
      } catch (error) {
        // Never include personal data in logs.
        console.error(
          JSON.stringify({
            event: "token_hard_delete_failed",
            tokenId: tokenId,
            message: error.message,
          })
        );
      }
    }

    console.log(
      `deleteScheduled: ${processed}/${expired.size} request(s) completed`
    );
    return null;
  });

async function processDeletion({ db, bucket, drive, tokenId, requestDoc }) {
  const counts = {
    firestoreDocs: 0,
    storageFiles: 0,
    driveFiles: 0,
  };

  const tokenRef = db.collection(TOKENS).doc(tokenId);
  const tokenSnap = await tokenRef.get();

  // Consent metadata for the tombstone (deleted afterwards).
  const consentSnap = await db
    .collection(CONSENT_RECORDS)
    .where("subjectId", "==", tokenId)
    .limit(5)
    .get();
  let consentGivenAt = null;
  let consentVersion = null;
  if (!consentSnap.empty) {
    const consentData = consentSnap.docs[0].data();
    consentVersion =
      typeof consentData.consent_version === "number"
        ? consentData.consent_version
        : null;
    const timestamp = consentData.timestamp;
    if (timestamp && typeof timestamp.toDate === "function") {
      consentGivenAt = timestamp.toDate();
    }
  }

  const requestData = requestDoc.data() || {};
  const withdrawnAt =
    requestData.requestedAt && typeof requestData.requestedAt.toDate === "function"
      ? requestData.requestedAt.toDate()
      : null;

  // 1) Token subcollection documents (children, documents metadata).
  for (const subcollectionName of ["children", "documents"]) {
    const subcollection = await tokenRef.collection(subcollectionName).get();
    for (const doc of subcollection.docs) {
      await doc.ref.delete();
      counts.firestoreDocs += 1;
    }
  }

  // 2) Token document itself.
  if (tokenSnap.exists) {
    await tokenRef.delete();
    counts.firestoreDocs += 1;
  }

  // 3) Storage objects for the token.
  const prefix = `tokens/${tokenId}/`;
  try {
    const [files] = await bucket.getFiles({ prefix: prefix });
    for (const file of files) {
      await file.delete();
      counts.storageFiles += 1;
    }
  } catch (storageError) {
    console.error(
      JSON.stringify({
        event: "storage_delete_failed",
        tokenId: tokenId,
        message: storageError.message,
      })
    );
  }

  // 4) Drive copies via the fileId mapping written by syncStorageToDrive.
  //    Files mirrored before that mapping existed are reported as a gap.
  const mappings = await db
    .collection(DRIVE_MIRROR)
    .where("tokenId", "==", tokenId)
    .get();
  let driveGapFiles = 0;
  if (counts.storageFiles > mappings.size) {
    driveGapFiles = counts.storageFiles - mappings.size;
  }
  for (const mapping of mappings.docs) {
    const fileId = mapping.data().driveFileId;
    if (fileId) {
      try {
        await drive.files.delete({ fileId: fileId, supportsAllDrives: true });
        counts.driveFiles += 1;
      } catch (driveError) {
        console.error(
          JSON.stringify({
            event: "drive_delete_failed",
            tokenId: tokenId,
            message: driveError.message,
          })
        );
      }
    }
    await mapping.ref.delete();
    counts.firestoreDocs += 1;
  }
  if (driveGapFiles > 0) {
    console.warn(
      JSON.stringify({
        event: "drive_mapping_gap",
        tokenId: tokenId,
        unmappedFiles: driveGapFiles,
        note: "pre-mapping Drive copies cannot be deleted automatically",
      })
    );
  }

  // 5) Consent records: delete after extracting metadata (they carry the
  //    subjectId and consent hashes, which must not outlive the data).
  for (const consentDoc of consentSnap.docs) {
    await consentDoc.ref.delete();
    counts.firestoreDocs += 1;
  }

  // 6) Non-personal tombstone.
  const tombstone = {
    tokenId: tokenId,
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (consentGivenAt) {
    tombstone.consentGivenAt = admin.firestore.Timestamp.fromDate(consentGivenAt);
  }
  if (consentVersion !== null) {
    tombstone.consentVersion = consentVersion;
  }
  if (withdrawnAt) {
    tombstone.withdrawnAt = admin.firestore.Timestamp.fromDate(withdrawnAt);
  }
  // Safety check: only whitelisted keys may reach the tombstone.
  for (const key of Object.keys(tombstone)) {
    if (!TOMBSTONE_FIELDS.includes(key)) {
      throw new Error(`tombstone field not allowed: ${key}`);
    }
  }
  await db.collection(DELETED_TOKENS).doc(tokenId).set(tombstone);

  // 7) Mark the request executed (audit trail only; no personal data).
  await requestDoc.ref.update({
    status: "executed",
    executedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(
    JSON.stringify({
      event: "token_hard_deleted",
      tokenId: tokenId,
      at: new Date().toISOString(),
      counts: counts,
      tombstoneFields: Object.keys(tombstone),
    })
  );

  return counts;
}
