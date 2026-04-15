# RTE Token Manager & Status Hub 🇮🇳

A high-performance, enterprise-grade Flutter application designed to streamline the **Right to Education (RTE)** admission and tracking process. This dual-purpose platform serves both parents and administrative office staff with a secure, real-time data ecosystem.

---

## 🌟 Core Modules

### 1. Unified Office Dashboard (Staff Side)
A secure administrative control center for managing the end-to-end mission process.
- **Biometric-inspired Authentication**: Firestore-backed login system with brute-force protection (3-attempt lockout).
- **Token Lifecycle Management**: Generate and manage unique application tokens for new families.
- **Smart Government Hub**: Direct integration with the formal RTE portal for instant status verification.
- **Intelligent Audit Logs**: Local search history with timestamps and one-tap autofill for high-speed administrative oversight.
- **QR Operations**: Integrated scanner for verifying parent application tokens at the physical office.

### 2. Parent Interactive Portal (Parent Side)
A mobile-first experience for parents to stay connected with their application's progress.
- **Secure Token Access**: Instant entry via unique tokens or QR code scanning.
- **Document Management**: Centralized hub for uploading and viewing application-required documents.
- **Live Status Feed**: Real-time progress tracking from submission to final approval.
- **Child Profile Hub**: Comprehensive management of student details and metadata.

### 3. Automated Document Mirroring (Cloud Infrastructure)
A high-efficiency background system that ensures all physical documents are redundant and easily accessible via Google Drive.
- **Real-time Sync**: Automated trigger via Firebase Cloud Functions whenever a file is finalized in Storage.
- **Enterprise-ready Quota**: Integrated **OAuth 2.0 (Refresh Token)** flow to leverage your **5TB Google Drive storage**, bypassing the limitations of standard service accounts.
- **Smart Organization**: Automatically categorizes documents into specific sub-folders based on Application Tokens (e.g., `Token_104`, `Token_105`).
- **Conflict Management**: Intelligent logic to detect existing files and perform atomic updates or creations as needed.

---

## 🚀 Key Features

- **Enterprise Security**: Implemented persistent sessions and role-based access control.
- **Advanced Data Retrieval**: Proprietary government portal bridge for automated verification (RequestVerificationToken handling).
- **Premium Aesthetics**: Dark-teal professional theme with glassmorphism, responsive animations, and Google Fonts typography.
- **Real-time Persistence**: Full Google Firebase (Firestore & Storage) integration for live cross-device data syncing.
- **Efficient Workflow**: Automatic form resets, keyboard management, and local caching for optimized staff productivity.

---

## 🛠 Technical Architecture

- **Engine**: Flutter (Dart)
- **Database**: Cloud Firestore (Real-time NoSQL)
- **File Storage**: Firebase Storage & Google Drive (Bi-cloud redundancy)
- **Backend Logic**: Firebase Cloud Functions (Node.js 20)
- **Authentication**: Firebase Auth & OAuth 2.0 (Google Workspace integration)
- **Networking**: Dio (Advanced HTTP client with interceptors)
- **Navigation**: GoRouter (Declarative routing system)

---

## 🏁 Installation & Development

1. **Clone the Repository**
   ```bash
   git clone https://github.com/bhoraniaarshadali/rte-app.git
   ```

2. **Configure Firebase**
   - Ensure `google-services.json` is correctly placed in `android/app/`.

3. **Cloud Functions Setup**
   - Navigate to `/functions`
   - Install dependencies: `npm install`
   - Setup OAuth credentials in `index.js`
   - Deploy: `firebase deploy --only functions`

4. **Launch Application**
   ```bash
   flutter run
   ```

---

## 📅 Major Update: Aadhaar Workflow & UI Hardening

### 🚀 High-Performance Aadhaar Overhaul
Implemented a mission-critical, high-performance Aadhaar document management system:
- **Clean Flow Architecture**: Forced guided workflow: **Capture Front ➔ Crop ➔ Capture Back ➔ Crop ➔ Background Merge ➔ Full-Screen Preview ➔ Final Upload**.
- **Background Image Merging**: Heavy image processing (decoding/merging) offloaded to background isolates using `compute()` to ensure 60fps UI performance.
- **Intelligent Memory Protection**: Automated resolution management that resizes high-res captures (max 1000px height) before merging to prevent **Out-of-Memory (OOM)** crashes on budget devices while maintaining text legibility.
- **Full-Screen Interactive Preview**: A new dedicated preview screen with **Pinch-to-Zoom** and interactive verification steps before final submission.

### 🎨 Premium UI/UX Enhancements
- **Modern Processing Overlays**: Redesigned the "Wait for Processing" UI with a semi-transparent blur, centered premium white-cards, and smooth circular loaders (replacing basic system loaders).
- **Legibility Updates**: Unified all system **SnackBars** to use high-contrast white text styles for instant readability on both success (green) and error (red) states.
- **Smarter Government Status**: refined the portal feedback system—"No status information found" is now treated as a neutral grey state with a clear "DATA NOT FOUND" label, improving user perception.

### 📋 Document Management Expansion
- **Extended Mandatory Set**: Now requires **7 core documents**, including the newly added `Child Aadhaar Card` and `Parent Signature`.
- **Dynamic Doc Vault**: Added support for up to **3 additional custom documents** (e.g., Caste Certificate) with unique naming and dedicated storage paths.

---

## 🔌 Plug & Play: Migration & Deployment Guide

This section outlines how to migrate the entire system (App + Firebase + Google Drive Sync) to a completely new account or environment.

### 1. Firebase Project Setup (The Foundation)
1.  Create a new project on the [Firebase Console](https://console.firebase.google.com/).
2.  Enable **Firestore Database** in test mode initially, then update rules.
3.  Enable **Firebase Storage**.
4.  Activate **Google Authentication** (optional) or ensure email/pass is enabled if needed.
5.  **Android App**: Register your app with package name `com.example.rte_status_checker`.
6.  **Google-Services**: Download the new `google-services.json` and replace the one in `android/app/`.

### 2. Google Cloud & Drive API (The Sync Hub)
To sync files to a new Google Drive:
1.  Go to [Google Cloud Console](https://console.cloud.google.com/).
2.  Select your Firebase project.
3.  **Enable APIs**: Enable the **Google Drive API**.
4.  **OAuth Consent Screen**:
    - Select "External".
    - Add `.../auth/drive.file` and `.../auth/drive` scopes.
    - Add your email as a **Test User** (Crucial: OAuth won't work without this in testing).
5.  **Credentials**: 
    - Create an **OAuth 2.0 Client ID** (Type: Web Application).
    - Note down your **Client ID** and **Client Secret**.
6.  **Refresh Token**: Use an OAuth playground or a script to authorize your account and get the **Refresh Token**.

### 3. Cloud Functions (The Engine)
1.  Navigate to the `/functions` folder in the project.
2.  Open `index.js` and update these constants with your new credentials:
    ```javascript
    const CLIENT_ID = 'YOUR_NEW_CLIENT_ID';
    const CLIENT_SECRET = 'YOUR_NEW_CLIENT_SECRET';
    const REFRESH_TOKEN = 'YOUR_NEW_REFRESH_TOKEN';
    const DRIVE_FOLDER_ID = 'YOUR_TARGET_GOOGLE_DRIVE_FOLDER_ID';
    ```
3.  **Deploy**: Run `firebase use <new-project-id>` followed by `firebase deploy --only functions`.

### 4. Database Initialization
Ensure the following collections exist or are initialized via first use:
- `tokens`: Primary token store.
- `meta`: Store `token_counter` doc with `{ "current": 100 }` to start token numbering.

### 5. Final Build
- Run `flutter clean` ➔ `flutter pub get`.
- Build the APK or run the app. It will now point to the new Firebase project and sync documents to the new Google Drive account.

---

*Engineered with precision by [Arshadalibhorania](https://github.com/bhoraniaarshadali)*
