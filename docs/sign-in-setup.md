# Turning on sign-in (dev project)

The sign-in code (Google and email link, T-2.2) is in the app. Each staging build sets up as much
of Firebase as it can with the `FIREBASE_SERVICE_ACCOUNT` secret, in the step **Set up sign-in in
Firebase** of `.github/workflows/distribute-staging.yml` (`.github/scripts/firebase-sign-in-setup.sh`):

- registers the SHA-1 and SHA-256 of the key that signs the build with the Android app
  `com.lingomate.app.dev`;
- turns on Anonymous and Email link (passwordless) sign-in;
- downloads a fresh `google-services.json` and builds with it once it has OAuth clients.

The run summary lists what was done and what is left. Live on dev and test builds does not need
sign-in: those builds carry their own Gemini key (`GEMINI_API_KEY`). Production Live keeps asking
for an account, because its tokens come from the `issueLiveToken` Cloud Function.

## What only the owner can do

The summary says which of these are needed:

1. **Permission denied**: Google Cloud console → IAM & Admin → IAM (project `lingo-mate-4f38d`) →
   edit the service account in `FIREBASE_SERVICE_ACCOUNT` → add the role **Firebase Admin**.
2. **Authentication is not started**: Firebase console → Build → Authentication → **Get started**.
3. **Google sign-in: off**: Firebase console → Authentication → Sign-in method → **Google** →
   Enable → pick the support email → Save. The web OAuth client Google sign-in needs is only
   created by this console switch.

Then build staging again.

## Afterwards

When the summary says `google-services.json` was refreshed, commit the version printed in that
step's log as `android/app/src/dev/google-services.json`, so local builds get it too. If you also
build on your own machine, add your debug key's fingerprints in Project settings → Your apps:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

To check, install the new build and open Me → Sign in → Continue with Google, then Continue with
email. The link opens the app on the same phone.
