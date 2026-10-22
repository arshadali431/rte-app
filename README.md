# RTE Token Manager & Status Hub 🇮🇳

A Flutter + Firebase application that helps an office issue and track **Right to Education
(RTE)** application tokens, lets parents view their application status and upload documents,
and mirrors uploaded documents to Google Drive through a Cloud Function.

> ## ⚠️ Read this before using the app with real families
>
> This codebase is a feature-rich **prototype that is not yet safe for production**:
> - Firestore and Storage security rules are currently wide open
>   (`allow read, write: if true`) — see `firestore.rules` / `storage.rules` and the
>   deny-all drafts `firestore.rules.locked` / `storage.rules.locked`.
> - There is **no server-side authentication** yet. Office login is a client-side check and
>   the parent portal identifier is a sequential token number.
> - TLS certificate validation is disabled globally in the app (`lib/main.dart`) — a P0
>   finding that is **not** part of this secrets cleanup and is still open.
>
> `PROJECT_AUDIT.md` contains the full audit, `CREDENTIALS.md` the credential/handover
> register. **Do not process real applicant or Aadhaar data until the P0 findings are fixed.**

---

## Core modules

### 1. Office dashboard (staff)
- Token lifecycle: transactional token-number allocation, parent details, application id/DOB.
- Government status hub: fetches the RTE Gujarat application status from the official portal.
- Search and audit history: token number, application id, mobile, name, and recent activity.
- Document vault: upload/view required documents, including a guided Aadhaar front/back
  capture → crop → merge → preview → upload flow.
- QR operations: render a token QR for parents and scan it at the office desk.
- Bulk status sync: chunked, cursor-paginated sync with a staff-facing password prompt
  (client-side, legacy — to be replaced by server-side authorisation).

### 2. Parent portal
- Token access by scanning the QR printed by the office (no manual token entry yet).
- Live application status and document list from Firestore.
- Document upload with camera/gallery, crop, compression and permission handling.
- Child profile management (name, DOB, Aadhaar number, school preferences).

### 3. Document mirroring (Cloud Function)
- Firestore/Storage `onFinalize` trigger copies each `tokens/<id>/<file>` object to a
  Google Drive folder named `Token_<id>`.
- OAuth2 credentials are read from **Google Cloud Secret Manager** via
  `firebase-functions/params` (`defineSecret`) — never from source code.
  See `CREDENTIALS.md`.

---

## Technical architecture

- **App**: Flutter (Dart 3), GoRouter navigation, Provider for two app-wide flags.
- **Data**: Cloud Firestore (tokens, children, documents, meta, admin config).
- **Files**: Firebase Storage, mirrored to Google Drive by the Cloud Function.
- **Backend logic**: Firebase Cloud Functions (Node.js 20, `firebase-functions` v5).
- **Auth**: *not implemented server-side.* The app has no Firebase Auth dependency; office
  sessions are a local flag and parents are identified by a token id. This is the largest
  open item in `PROJECT_AUDIT.md`.
- **Networking**: Dio + `html` parsing for the government portal.
- **Secrets**: Secret Manager for the function; `android/key.properties` (git-ignored) for
  release signing. Nothing secret is committed.

---

## Installation & development

1. **Clone**
   ```bash
   git clone https://github.com/bhoraniaarshadali/rte-app.git
   cd rte-app
   ```

2. **Firebase client config**
   - Place `google-services.json` in `android/app/` and keep `lib/firebase_options.dart`
     in sync with your Firebase project (both are public client identifiers, not secrets).

3. **Cloud Functions**
   ```bash
   cd functions
   npm install
   cd ..
   ```
   Create the function secrets (the CLI prompts for values, they are never committed):
   ```bash
   firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_ID
   firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_SECRET
   firebase functions:secrets:set GOOGLE_DRIVE_REFRESH_TOKEN
   firebase functions:secrets:set DRIVE_ROOT_FOLDER_ID
   firebase deploy --only functions
   ```
   See `CREDENTIALS.md` for how to obtain these values and the rotation procedure.

4. **Run the app**
   ```bash
   flutter pub get
   flutter run
   ```

5. **Secret scanning + git hooks (recommended for every clone)**
   ```bash
   git config core.hooksPath .githooks    # pre-commit gitleaks scan (if gitleaks is installed)
   ```
   A GitHub Actions workflow (`.github/workflows/secret-scan.yml`) scans pushes/PRs.
   Never commit `.env`, `key.properties`, keystore files or service-account keys — the root,
   `functions/` and `import_data/` ignore files cover them.

---

## Google Cloud / Drive setup (for the mirror function)

1. Create/select the Firebase project and enable the **Google Drive API** in Google Cloud.
2. OAuth consent screen: add only **`.../auth/drive.file`** (least privilege). Do **not** request
   full `.../auth/drive`; anything wider exposes the whole Drive if the token leaks.
3. Create an OAuth 2.0 Client (type: Web application) and obtain a refresh token through the
   OAuth playground or your own script. Store the values only in Secret Manager.
4. Create a Drive folder for the mirror and store its id as `DRIVE_ROOT_FOLDER_ID`.

## Database initialization

- `tokens`: token documents, id = token number.
- `meta/token_counter`: `{ "lastTokenNumber": <n> }` — the next token is `n + 1`.
- `rte-2026-27/admin`: legacy admin/maintenance document (currently holds plaintext
  credentials — must be migrated to hashed credentials + Firebase Auth; see the audit).

## Known limitations (see `PROJECT_AUDIT.md` for the full list)

- No Firebase Auth / RBAC; open Firestore and Storage rules.
- Parent portal has no manual token entry fallback.
- iOS Firebase configuration is not wired into the Xcode target.
- Release builds use the debug keystore unless `android/key.properties` exists.
- `com.example.*` application ids must be changed before store submission.
- `google_fonts/` asset directory is referenced by `pubspec.yaml` but is empty (fonts are
  fetched at runtime); a clean clone may need that entry fixed before building.
- The only test is the default Flutter counter template (no real coverage).

---

*Engineered by [Arshadalibhorania](https://github.com/bhoraniaarshadali), hardened after the
2026-10-22 security audit.*
