# Credentials register — RTE Status Checker

**Purpose:** one place that records *every* credential the project needs, *where the real value
lives*, *who owns it*, and *how to rotate it* — without ever storing the value itself.

> **This file contains NO secret values.** Never paste a real client secret, refresh token,
> private key, API key, password or keystore password into this file, an issue, a chat, a
> commit message or a screenshot. Reference credentials only by their environment/secret name.

**Project:** `rte-app-52b7e` · **Repo:** `github.com/bhoraniaarshadali/rte-app` · **Last verified:** 2026-10-22

---

## 1. Current security state (read first)

| Item | Status (2026-10-22) |
|---|---|
| OAuth client id / secret / refresh token in `functions/index.js` | **Removed from source.** Function now reads them from Secret Manager via `defineSecret`. |
| Same credentials in git **history** | **Still present** (added in commit `ee621b9`). Rotation + history purge are MANUAL steps — see §4. Treat the previously committed values as compromised. |
| Credentials rotated/revoked | **Not done yet — manual work by the owner.** |
| Firestore / Storage rules | **Still open** (`allow read, write: if true`). Deny-all drafts exist in `firestore.rules.locked` / `storage.rules.locked`; not deployed. |
| Firebase Authentication | **Not implemented.** Office/parent "auth" is client-side only (see `PROJECT_AUDIT.md` P0-3). |
| Release signing | Reads `android/key.properties` when present; falls back to the debug keystore otherwise. No real keystore exists yet. |

---

## 2. Credential inventory

| # | Name (env / secret) | Purpose | Where it is used | Where the real value lives | Owner | Rotation / revocation |
|---|---|---|---|---|---|---|
| 1 | `GOOGLE_OAUTH_CLIENT_ID` | Identifies the OAuth2 client used to authorise Drive uploads | `functions/index.js` (Secret Manager param) | Google Cloud Secret Manager for project `rte-app-52b7e`; source: GCP Console → APIs & Services → Credentials → OAuth 2.0 Client | Repo owner (Arshad ali bhorania) | Create new OAuth client → `firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_ID` → redeploy |
| 2 | `GOOGLE_OAUTH_CLIENT_SECRET` | Secret half of the OAuth2 client | `functions/index.js` (Secret Manager param) | Secret Manager; GCP Console → Credentials | Repo owner | Delete/reset client secret in GCP → set new secret value → redeploy. **Previously leaked in git history — rotate.** |
| 3 | `GOOGLE_DRIVE_REFRESH_TOKEN` | Long-lived token to mint Drive access without interactive login | `functions/index.js` (Secret Manager param) | Secret Manager; issued by the Google account that owns the Drive folder | Repo owner | Revoke at `myaccount.google.com/permissions` → re-authorise with **`drive.file` scope only** → set new secret value → redeploy. **Previously leaked in git history — revoke now.** |
| 4 | `DRIVE_ROOT_FOLDER_ID` | Target Drive folder that mirrors all token documents | `functions/index.js` (Secret Manager param) | Secret Manager; the Drive URL of the folder | Repo owner | Create new folder in Drive → set secret value → redeploy. Not a credential, but kept out of source so the backup location is not public. |
| 5 | Firebase **Android** API key | Client identifier used by the Firebase SDK (also access to public Firebase endpoints) | `lib/firebase_options.dart`, `android/app/google-services.json` | Committed client config (**public identifier by design** — it is not a secret) | Repo owner | Restrict in GCP → API Keys (package name + SHA-256 + needed APIs); rotate if abused. Do **not** treat as a secret. |
| 6 | Firebase **iOS** API key | Same, iOS | `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist` | Committed client config (**public identifier by design**) | Repo owner | Restrict to iOS bundle id + API Key restrictions; rotate if abused. |
| 7 | Firebase **service-account key** | Admin SDK credential used by local tooling (`functions/service-account.json`) | Local file only (git-ignored, untracked; **not** used by the deployed import script anymore) | `functions/service-account.json` on the owner's machine; never in git | Repo owner | IAM → Service Accounts → Keys → create new key, delete old → update local file / CI secret. Never commit. Also exclude from the Functions deploy source (see `firebase.json` ignore list). |
| 8 | Office login password (`password` field) | Legacy office login credential | `rte-2026-27/admin` Firestore doc; read by `lib/services/auth_service.dart` | Firestore document (currently **plaintext** — must be hashed server-side) | Repo owner / office admin | Change the value in Firestore (then hash it), force staff re-login. Assume compromised while rules are open. |
| 9 | Bulk-sync password (`syncing_password` field) | Legacy gate for the government-portal bulk sync | `rte-2026-27/admin` Firestore doc; read by `lib/screens/office/office_dashboard_screen.dart` | Firestore document (currently **plaintext**) | Repo owner / office admin | Change the value; remove the client-side gate and authorise the operation server-side. |
| 10 | Firebase project id / app ids | Public project identifiers (`rte-app-52b7e`, app ids) | `firebase.json`, `.firebaserc`, `lib/firebase_options.dart`, `android/app/google-services.json` | Committed config | Repo owner | Not secret. Keep in sync when migrating projects. |
| 11 | Android release keystore + passwords | Signs release APK/AAB | `android/app/build.gradle.kts` reads `android/key.properties` → `.jks` file | `android/key.properties` + the keystore file on the owner's machine / secure CI secret store (both git-ignored) | Repo owner | Generate with `keytool` (owner's decision on alias/passwords) → store passwords in `key.properties` locally + CI secret → back up the keystore securely (Play App Signing strongly recommended). |
| 12 | `IMPORT_SHEET_CSV_URL` | CSV export URL of the applicant Google Sheet used by the import tool | `import_data/import_from_sheet.js` (environment variable) | Local/CI environment (`.env`, git-ignored); the sheet itself is link-shared | Repo owner | Make the sheet private / re-share with a new link → update the env var. |
| 13 | GitHub secret-scanning licence/config | Enables the CI secret scan (workflow `.github/workflows/secret-scan.yml`) | GitHub Actions | Repo settings; `.gitleaks.toml` in repo (no secret) | Repo owner | n/a |

**Explicitly not credentials:** `google-services.json`, `firebase_options.dart` and
`GoogleService-Info.plist` contain Firebase API keys that are *public identifiers* required in
every client build. Do not "fix" them by removing the keys — restrict them in GCP instead.

---

## 3. Account ownership

Fill in the real owner identities before handover (these are accounts, not secrets).

| Asset | Owner (name / email) | Notes |
|---|---|---|
| Google account that owns the Drive folder | _[FILL IN]_ | The refresh token (§2 #3) acts as this account for `drive.file` access |
| Google Cloud / Firebase project `rte-app-52b7e` | _[FILL IN]_ | Owns Secret Manager, OAuth client, service accounts |
| Play Console developer account | _[FILL IN]_ | Needed for release signing / app bundle |
| App Store Connect team | _[FILL IN]_ | iOS release not yet started |
| GitHub repository `bhoraniaarshadali/rte-app` | _[FILL IN]_ | Make private; enable secret scanning + push protection |
| Office admin (Firestore `rte-2026-27/admin`) | _[FILL IN]_ | Owns the office login / sync passwords |
| Server / billing owner | _[FILL IN]_ | Firebase billing, budget alerts, quotas |

---

## 4. Mandatory order of operations (do not reorder)

1. **Revoke** the leaked refresh token at `myaccount.google.com/permissions`
   (Workspace: Admin console → Security → API controls). This kills the leaked token immediately.
2. **Rotate** the OAuth client secret (GCP → APIs & Services → Credentials → delete/reset the client).
3. **Rotate** the service-account key (IAM → Service Accounts → Keys) and remove the old key.
4. **Re-issue** credentials with the narrowest scope: `drive.file` only (never full `drive`).
5. **Store** values in Secret Manager and set them for the function:
   ```bash
   firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_ID
   firebase functions:secrets:set GOOGLE_OAUTH_CLIENT_SECRET
   firebase functions:secrets:set GOOGLE_DRIVE_REFRESH_TOKEN
   firebase functions:secrets:set DRIVE_ROOT_FOLDER_ID
   ```
   (Each command prompts for the value; it is never echoed or written to the repo.)
6. **Audit** usage of the old credentials: Google account activity / Drive audit log / GCP audit logs /
   Storage & Firestore access logs. Record findings.
7. **Purge git history** — only *after* rotation. Owned by the user; requires `git filter-repo`
   (or BFG) + force-push and coordination with every clone/fork. See §6.
8. **Make the Git repository private**, enable GitHub secret scanning + push protection.
9. **Deploy rules** only after an authentication model exists (see `firestore.rules.locked`).
10. **Rotate the office/sync passwords** and move auth server-side (hashed, Firebase Auth).

> Rotation *before* history purge: history rewriting does not revoke anything, and every clone or
> fork keeps the old value. Rotation is the step that actually stops the exposure.

---

## 5. Handover checklist

- [ ] All rows in §2 and §3 have an owner and current rotation date
- [ ] Secret Manager contains all four `GOOGLE_*`/`DRIVE_*` secrets for the project
- [ ] `firebase functions:secrets:access <NAME>` works for the function's service account
- [ ] No secret values exist in tracked files (`gitleaks detect --no-git` passes)
- [ ] Git history purged and force-pushed **after** rotation; all collaborators re-cloned
- [ ] GitHub repo private; secret scanning + push protection enabled
- [ ] `android/key.properties` + keystore exist in the owner's secure store, not in git
- [ ] Firestore/Storage rules deployed and verified deny-by-default + auth-based access
- [ ] Office/sync passwords rotated; plaintext credentials removed from Firestore
- [ ] Incident note recorded (what leaked, when, what was rotated, who was notified)
- [ ] `PROJECT_AUDIT.md` P0 findings reviewed and tracked to closure

---

## 6. Git history purge (owner-run, after rotation)

The leaked OAuth values entered history in commit `ee621b9` and are on `origin/main`. Local
`git filter-repo` example (review before running; coordinate force-push with collaborators):

```bash
# One-time install: pip install git-filter-repo
git filter-repo --replace-text secrets-replacements.txt --path functions/index.js
# where secrets-replacements.txt contains, one per line:
#   GOCSPX->***REMOVED***
#   1//->***REMOVED***
git remote add origin <repo-url>   # filter-repo removes the remote
git push --force --all && git push --force --tags
```

Also file a request with GitHub Support to expire cached views of the old commits, and assume
forks/clones still hold the values — rotation (§4 steps 1–3) is what protects the data.

---

## 7. Incident note

- **What:** OAuth2 client secret + long-lived Drive refresh token were committed to
  `functions/index.js` in commit `ee621b9` (2026-04-13) and remained on `origin/main`.
- **Exposure window:** 2026-04-13 → rotation date. Repository visibility unverified; assume public.
- **Detected by:** project security audit, 2026-10-22 (`PROJECT_AUDIT.md` P0-1).
- **Remediation in code:** hardcoded values removed; function now uses Secret Manager via
  `defineSecret`/`runWith({ secrets })`. Import tool now uses ADC/env. Secret-scan guard added.
- **Remediation pending (manual):** revocation, rotation, history purge, repo privacy, audit logs.
