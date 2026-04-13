const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const path = require("path");
const os = require("os");
const fs = require("fs");

admin.initializeApp();

// OAuth2 Credentials (EXACTLY from user feedback)
const CLIENT_ID = "753886667691-8dma9c1hksvcuv9oes26idcsbedo1tdr.apps.googleusercontent.com";
const CLIENT_SECRET = "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";
const REFRESH_TOKEN = "1//046GrAJ9r3AyqCgYIARAAGAQSNwF-L9IrmbC-AhOJE0Zx72EP0BCq7YgJLvBHSCM58puMLd559ZDi2WmgxSEWId23v79pLfzwxDo";

const oauth2Client = new google.auth.OAuth2(
  CLIENT_ID,
  CLIENT_SECRET,
  "https://developers.google.com/oauthplayground"
);

oauth2Client.setCredentials({ refresh_token: REFRESH_TOKEN });

const drive = google.drive({ version: "v3", auth: oauth2Client });
const ROOT_FOLDER_ID = "1bpGXfiaflHi5b-KRfNdyNS9lB6I9HX-k";

exports.syncStorageToDrive = functions
  .runWith({ memory: "512MB", timeoutSeconds: 300 })
  .storage.object()
  .onFinalize(async (object) => {
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
      
      const tokenFolderId = await getOrCreateFolder(`Token_${tokenId}`, ROOT_FOLDER_ID);
      
      const bucket = admin.storage().bucket(object.bucket);
      const tempFilePath = path.join(os.tmpdir(), fileName);
      await bucket.file(filePath).download({ destination: tempFilePath });

      const existingFile = await findFileInFolder(fileName, tokenFolderId);
      
      const media = {
        mimeType: contentType,
        body: fs.createReadStream(tempFilePath),
      };

      if (existingFile) {
        await drive.files.update({
          fileId: existingFile,
          media: media,
          supportsAllDrives: true,
        });
        console.log(`Sync Success (Update): ${fileName}`);
      } else {
        await drive.files.create({
          requestBody: { name: fileName, parents: [tokenFolderId] },
          media: media,
          supportsAllDrives: true,
        });
        console.log(`Sync Success (Create): ${fileName}`);
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

async function getOrCreateFolder(folderName, parentId) {
  const response = await drive.files.list({
    q: `name='${folderName}' and '${parentId}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false`,
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

async function findFileInFolder(fileName, folderId) {
  const response = await drive.files.list({
    q: `name='${fileName}' and '${folderId}' in parents and trashed=false`,
    fields: "files(id, name)",
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  });

  if (response.data.files && response.data.files.length > 0) {
    return response.data.files[0].id;
  }
  return null;
}
