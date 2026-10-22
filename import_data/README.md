# Google Sheets → Firestore importer

Imports application rows from a Google Sheet (CSV export) into the RTE Status Checker
Firestore database.

## Prerequisites

- Node.js 20+.
- **Credentials: Application Default Credentials (ADC).** No key file belongs in this repo.
  - Local: `gcloud auth application-default login`, **or**
    `GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/outside-the-repo.json`
  - CI: runner workload identity / ADC.
- The sheet's CSV export URL must be provided through `IMPORT_SHEET_CSV_URL`.

## Setup

```bash
cd import_data
npm install
cp .env.example .env       # then fill in IMPORT_SHEET_CSV_URL locally (never commit .env)
```

## How it works

1. Downloads the sheet as CSV from `IMPORT_SHEET_CSV_URL`.
2. Maps columns: **Token No** → doc id + `tokenNumber`, **Application Id** → `applicationId`,
   **બાળક ની જન્મ તારીખ** → `childDob`, **કોને ફોર્મ ભર્યું છે?** → `parentName`,
   **Timestamp** → `createdAt`.
3. Creates missing token records (status `pending`) and fills missing Application Id/DOB on
   existing ones without overwriting history.
4. Raises `meta/token_counter.lastTokenNumber` when the sheet contains higher token numbers.

## Usage

```bash
cd import_data
node import_from_sheet.js
```

Run with the `.env` loaded (for example `node --env-file=.env import_from_sheet.js`, or export
the variables in your shell).

## Notes

- Parent mobile numbers are not in the sheet, so they are left empty for the app's sync feature
  to fill from the government portal.
- Keep the sheet private or share it only with the intended account. A link-shared CSV export
  is readable by anyone with the link (`CREDENTIALS.md` #12).
- This tool is a one-off admin utility and is **not** covered by automated tests; prefer a
  Firestore emulator + dry-run before running it against production data.
