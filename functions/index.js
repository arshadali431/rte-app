const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const { defineSecret } = require("firebase-functions/params");
const path = require("path");
const os = require("os");
const fs = require("fs");

admin.initializeApp();

// ── Secrets ──────────────────────────────────────────────────────────────────
// OAuth credentials are NEVER hardcoded in source. These SecretParams are read
// from Google Cloud Secret Manager at runtime and injected only into this
// function (see the `secrets` array in runWith below).
//
// Create/update them once per environment with:
//   firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_ID
//   firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_SECRET
//   firebase functions:secrets:set GOOGLE_DRIVE_REFRESH_TOKEN
//   firebase functions:secrets:set DRIVE_ROOT_FOLDER_ID
//
// Ownership, rotation steps and handover checklist: see CREDENTIALS.md.
const GOOGLE_OAUTH_CLIENT_ID = defineSecret("GOOGLE_OAUTH_CLIENT_ID");
const GOOGLE_OAUTH_CLIENT_SECRET = defineSecret("GOOGLE_OAUTH_CLIENT_SECRET");
const GOOGLE_DRIVE_REFRESH_TOKEN = defineSecret("GOOGLE_DRIVE_REFRESH_TOKEN");
const DRIVE_ROOT_FOLDER_ID = defineSecret("DRIVE_ROOT_FOLDER_ID");

exports.syncStorageToDrive = functions
  .runWith({
    memory: "512MB",
    timeoutSeconds: 300,
    secrets: [
      GOOGLE_OAUTH_CLIENT_ID,
      GOOGLE_OAUTH_CLIENT_SECRET,
      GOOGLE_DRIVE_REFRESH_TOKEN,
      DRIVE_ROOT_FOLDER_ID,
    ],
  })
  .storage.object()
  .onFinalize(async (object) => {
    // Secret values are only readable inside a function invocation.
    const oauth2Client = new google.auth.OAuth2(
      GOOGLE_OAUTH_CLIENT_ID.value(),
      GOOGLE_OAUTH_CLIENT_SECRET.value(),
      "https://developers.google.com/oauthplayground"
    );
    oauth2Client.setCredentials({
      refresh_token: GOOGLE_DRIVE_REFRESH_TOKEN.value(),
    });
    const drive = google.drive({ version: "v3", auth: oauth2Client });
    const rootFolderId = DRIVE_ROOT_FOLDER_ID.value();

    const filePath = object.name;
    const contentType = object.contentType;

    if (!filePath || !filePath.startsWith("tokens/")) {
      console.log("Not a token file, skipping:", filePath);
      return null;
    }

    const parts = filePath.split("/");
    if (parts.length < 3) return null;

    const tokenId = parts[1];
    const fileName = parts[2];

    console.log(`OAuth Sync Attempt: tokenId=${tokenId}, file=${fileName}`);

    try {
      // Refresh token validation
      await oauth2Client.getAccessToken();

      const tokenFolderId = await getOrCreateFolder(
        drive,
        `Token_${tokenId}`,
        rootFolderId
      );

      const bucket = admin.storage().bucket(object.bucket);
      const tempFilePath = path.join(os.tmpdir(), fileName);
      await bucket.file(filePath).download({ destination: tempFilePath });

      const existingFile = await findFileInFolder(drive, fileName, tokenFolderId);

      const media = {
        mimeType: contentType,
        body: fs.createReadStream(tempFilePath),
      };

      let driveFileId = existingFile;
      if (existingFile) {
        await drive.files.update({
          fileId: existingFile,
          media: media,
          supportsAllDrives: true,
        });
        console.log(`Sync Success (Update): ${fileName}`);
      } else {
        const created = await drive.files.create({
          requestBody: { name: fileName, parents: [tokenFolderId] },
          media: media,
          supportsAllDrives: true,
        });
        driveFileId = created.data.id;
        console.log(`Sync Success (Create): ${fileName}`);
      }

      // Persist the Drive fileId so the scheduled hard-delete worker
      // (functions/deleteScheduled.js) can remove the mirrored copy later.
      // GAP: files mirrored before this change have no mapping row and cannot
      // be deleted automatically — see CREDENTIALS.md / task report.
      try {
        await admin
          .firestore()
          .collection("drive_mirror")
          .doc(`${tokenId}_${fileName}`)
          .set(
            {
              tokenId: tokenId,
              fileName: fileName,
              driveFileId: driveFileId,
              mimeType: contentType || null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
      } catch (mapError) {
        console.error("DRIVE MAP FAILED:", mapError.message);
      }

      fs.unlinkSync(tempFilePath);
      return null;
    } catch (error) {
      console.error("SYNC FAILED:");
      if (error.response) {
        console.error("Data:", JSON.stringify(error.response.data));
      } else {
        console.error("Error Message:", error.message);
      }
      return null;
    }
  });

/**
 * Escape a value used inside a Google Drive `q` search expression.
 * Single quotes and backslashes are the only characters that can break out of
 * the quoted literal, so they are escaped to prevent query injection from
 * Storage object names (tokens/<tokenId>/<fileName>).
 */
function escapeDriveQueryValue(value) {
  return String(value).replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

async function getOrCreateFolder(drive, folderName, parentId) {
  const safeFolderName = escapeDriveQueryValue(folderName);
  const safeParentId = escapeDriveQueryValue(parentId);
  const response = await drive.files.list({
    q: `name='${safeFolderName}' and '${safeParentId}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false`,
    fields: "files(id, name)",
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  });

  if (response.data.files && response.data.files.length > 0) {
    return response.data.files[0].id;
  }

  const folder = await drive.files.create({
    requestBody: {
      name: folderName,
      mimeType: "application/vnd.google-apps.folder",
      parents: [parentId],
    },
    fields: "id",
    supportsAllDrives: true,
  });

  return folder.data.id;
}

async function findFileInFolder(drive, fileName, folderId) {
  const safeFileName = escapeDriveQueryValue(fileName);
  const safeFolderId = escapeDriveQueryValue(folderId);
  const response = await drive.files.list({
    q: `name='${safeFileName}' and '${safeFolderId}' in parents and trashed=false`,
    fields: "files(id, name)",
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  });

  if (response.data.files && response.data.files.length > 0) {
    return response.data.files[0].id;
  }
  return null;
}

// ── Scheduled hard-delete worker (DRAFT — do NOT deploy without review) ─────
// Processes deletion_requests whose executeAfter has passed, removes all
// Firestore/Storage/Drive copies, and writes a non-personal tombstone.
exports.deleteScheduled = require("./deleteScheduled").deleteScheduled;
