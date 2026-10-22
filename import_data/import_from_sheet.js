const admin = require('firebase-admin');
const axios = require('axios');
const { parse } = require('csv-parse/sync');

// 1. Setup Firebase Admin
// Credentials are never committed. Uses Application Default Credentials (ADC):
//   local: gcloud auth application-default login, or
//          GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/outside-the-repo.json
//   CI:    workload identity / runner ADC
// Never point this at a key file stored inside the repository.
admin.initializeApp({
    credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

// 2. Configuration
const SHEET_URL = process.env.IMPORT_SHEET_CSV_URL;
if (!SHEET_URL) {
    console.error('Missing IMPORT_SHEET_CSV_URL (Google Sheets CSV export URL). See .env.example.');
    process.exit(1);
}
const TOKENS_COLLECTION = 'tokens';
const META_COLLECTION = 'meta';
const COUNTER_DOC = 'token_counter';

async function importData() {
    console.log('🚀 Starting Google Sheets Import...');

    try {
        // Fetch CSV data
        console.log('Fetching sheet data...');
        const response = await axios.get(SHEET_URL);
        const csvData = response.data;

        // Parse CSV
        const records = parse(csvData, {
            columns: true,
            skip_empty_lines: true,
            trim: true
        });

        console.log(`✅ Found ${records.length} records in sheet.`);

        let newRecordsCount = 0;
        let updatedRecordsCount = 0;
        let maxTokenNumber = 0;

        for (const record of records) {
            // Mapping Sheet Columns to Firestore Fields
            // Use exact column names found in the sheet
            const tokenNoStr = record['Token No'];
            const applicationId = record['Application Id'];
            const childDob = record['બાળક ની જન્મ તારીખ'];
            const parentName = record['કોને ફોર્મ ભર્યું છે?'];
            const timestampStr = record['Timestamp'];

            if (!tokenNoStr) continue;

            const tokenNumber = parseInt(tokenNoStr);
            if (isNaN(tokenNumber)) {
                console.warn(`⚠️ Skipping record with invalid Token Number: "${tokenNoStr}"`);
                continue;
            }
            if (tokenNumber > maxTokenNumber) maxTokenNumber = tokenNumber;

            const docId = `${tokenNumber}`;
            const tokenRef = db.collection(TOKENS_COLLECTION).doc(docId);
            const doc = await tokenRef.get();

            const dataToSet = {
                tokenNumber: tokenNumber,
                parentName: parentName || 'N/A',
                parentMobile: '', // Not available in sheet, setting empty
                applicationId: applicationId || null,
                childDob: childDob || null,
                status: 'pending',
                createdBy: 'Google Sheets Import',
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };

            // Add createdAt if it's a new record and we have a timestamp
            if (timestampStr) {
                // Approximate timestamp parsing (Google Sheets format is usually DD/MM/YYYY HH:mm:ss or similar)
                // If it fails, we use server timestamp
                try {
                    const parts = timestampStr.split(/[\/\s:]/);
                    if (parts.length >= 3) {
                        // Assumption: DD/MM/YYYY
                        const date = new Date(parts[2], parts[1] - 1, parts[0], parts[3] || 0, parts[4] || 0, parts[5] || 0);
                        if (!isNaN(date.getTime())) {
                            dataToSet.createdAt = admin.firestore.Timestamp.fromDate(date);
                        }
                    }
                } catch (e) {
                    console.warn(`⚠️ Could not parse timestamp: ${timestampStr}`);
                }
            }

            if (!doc.exists) {
                // New record
                if (!dataToSet.createdAt) {
                    dataToSet.createdAt = admin.firestore.FieldValue.serverTimestamp();
                }
                await tokenRef.set(dataToSet);
                newRecordsCount++;
                console.log(`[NEW] Token #${tokenNumber} added.`);
            } else {
                // Existing record - update only if needed or just skip
                // For this script, we'll merge updates for appId and Dob if they are null in DB
                const existingData = doc.data();
                const updates = {};
                
                if (!existingData.applicationId && applicationId) updates.applicationId = applicationId;
                if (!existingData.childDob && childDob) updates.childDob = childDob;
                if (!existingData.parentName && parentName) updates.parentName = parentName;

                if (Object.keys(updates).length > 0) {
                    await tokenRef.update(updates);
                    updatedRecordsCount++;
                    console.log(`[UPDATED] Token #${tokenNumber} updated with new info.`);
                }
            }
        }

        // 3. Update Token Counter if needed
        if (maxTokenNumber > 0) {
            const counterRef = db.collection(META_COLLECTION).doc(COUNTER_DOC);
            const counterSnap = await counterRef.get();
            const currentLast = counterSnap.exists ? (counterSnap.data().lastTokenNumber || 0) : 0;

            if (maxTokenNumber > currentLast) {
                await counterRef.set({ lastTokenNumber: maxTokenNumber }, { merge: true });
                console.log(`✅ Updated token counter to: ${maxTokenNumber}`);
            }
        }

        console.log('\n--- Import Summary ---');
        console.log(`Total records processed: ${records.length}`);
        console.log(`New records added: ${newRecordsCount}`);
        console.log(`Existing records updated: ${updatedRecordsCount}`);
        console.log('----------------------');

    } catch (error) {
        console.error('❌ Error during import:', error);
    } finally {
        console.log('Done.');
        process.exit();
    }
}

importData();
