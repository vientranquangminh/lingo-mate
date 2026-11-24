# CI/CD: dev builds to Firebase App Distribution

`.github/workflows/distribute-dev.yml` runs on every push to `main` (and by hand from
Actions → Build & Distribute Android (dev) → Run workflow). It analyzes, tests, builds the
`dev` flavor as a signed release APK (`com.lingomate.app.dev`, build number = run number)
and sends it to the tester groups of Firebase project `lingo-mate-4f38d` with the commit
message as release notes. The Firebase app id is read from `firebase.json`.

Until any of the secrets below exist, the workflow skips the build and reports a notice instead of failing, so merges send no failure emails. Once some are set, it fails within seconds if the rest are missing.

## 1. Release keystore (once)

Create it on your machine and keep a backup outside the repo: every build must be signed
with the same key, or testers cannot update over the previous install.

```bash
keytool -genkeypair -v -keystore lingomate-release.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

```bash
base64 -w0 lingomate-release.jks > lingomate-release.jks.b64
```

On macOS use `base64 -i lingomate-release.jks -o lingomate-release.jks.b64`.

To build release locally, copy the keystore to `android/app/key-release.jks` and create
`android/signing.properties` with `KEYSTORE_PASSWORD`, `KEY_ALIAS` and `KEY_PASSWORD`
(both are git-ignored).

## 2. Firebase

1. Firebase console → project `lingo-mate-4f38d` → App Distribution → Get started, for the
   Android app `com.lingomate.app.dev`.
2. Testers & Groups → add a group (e.g. alias `testers`) and its testers' emails.
3. Project settings → Service accounts → Manage service account permissions (Google Cloud
   console) → create a service account with the role **Firebase App Distribution Admin**
   → Keys → Add key → JSON. Download the JSON file.
4. Add the keystore's SHA-1 to the Android app (Project settings → Your apps), and to the
   Gemini API key's Android restriction, so the distributed build can use them:

   ```bash
   keytool -list -v -keystore lingomate-release.jks -alias upload
   ```

## 3. GitHub (Settings → Secrets and variables → Actions)

| Kind | Name | Value |
|---|---|---|
| Secret | `FIREBASE_SERVICE_ACCOUNT` | Full content of the service account JSON file |
| Secret | `ANDROID_KEYSTORE_BASE64` | Content of `lingomate-release.jks.b64` |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| Secret | `ANDROID_KEY_ALIAS` | `upload` (or the alias you chose) |
| Secret | `ANDROID_KEY_PASSWORD` | Key password |
| Secret | `GEMINI_API_KEY` | Dev Gemini API key (dev flavor only; optional, the build warns without it) |
| Secret | `APP_CHECK_DEBUG_TOKEN` | App Check debug token registered for the dev app (optional) |
| Variable | `FIREBASE_DISTRIBUTION_GROUPS` | Group alias(es), comma-separated, e.g. `testers` |

The dev APK carries the dev Gemini key, as `.env.dev` builds always do. Keep that key
restricted to `com.lingomate.app.dev` and the keystore's SHA-1, on the Spark plan.
