# Turning on sign-in (dev project)

The sign-in code (Google and email link, T-2.2) is in the app, but the Firebase project must be
set up before it works. Until then, Google sign-in shows "Google sign-in isn't set up for this
build yet", and the email link may not arrive.

Live on dev and test builds does not need sign-in: those builds carry their own Gemini key
(`GEMINI_API_KEY`), so no server token is involved. Production Live keeps asking for an
account, because its tokens come from the `issueLiveToken` Cloud Function.

## 1. Turn on the sign-in methods

Firebase console → project `lingo-mate-4f38d` → Build → Authentication → Get started →
Sign-in method:

1. **Anonymous** → Enable → Save. The app starts every user as anonymous and links the account
   on sign-in, so phrases are kept.
2. **Google** → Enable → pick the project support email → Save. This creates the web OAuth
   client the app needs.
3. **Email/Password** → Enable, and turn on **Email link (passwordless sign-in)** → Save.

Authentication → Settings → Authorized domains must list `lingo-mate-4f38d.firebaseapp.com`.
It is there by default.

## 2. Add the signing key fingerprints

Google sign-in only works for apps whose signing key Firebase knows.

1. Open the latest **Build & Distribute Android (staging)** run on GitHub Actions. Its summary
   shows the SHA-1 and SHA-256 of the key that signs the test builds.
2. Firebase console → Project settings → Your apps → Android `com.lingomate.app.dev` →
   **Add fingerprint**. Add the SHA-1, then the SHA-256.
3. If you also build on your own machine, add that key too:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   ```

When the test builds move to your own `ANDROID_*` keystore, or to Play App Signing for
release, add those fingerprints as well.

## 3. Update `google-services.json`

After steps 1 and 2, Project settings → Your apps → `com.lingomate.app.dev` → download
`google-services.json`. It now has an `oauth_client` section. Replace
`android/app/src/dev/google-services.json` with it and commit, or send it to the developer.
Without it, Google sign-in fails with a configuration error.

## 4. Check

Push to `staging`, install the new build, and open Me → Sign in → Continue with Google.
Then try Continue with email. The link opens the app on the same phone.
