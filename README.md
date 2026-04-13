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

*Engineered with precision by [Arshadalibhorania](https://github.com/bhoraniaarshadali)*
