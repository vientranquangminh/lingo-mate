# 04 — Integrations

Status: Draft v0.1 · Facts checked 2026-11-24 — APIs and prices change; re-verify against the linked docs when implementing.

Overview:

| # | Integration | Phase | Used for | Cost in dev |
|---|-------------|-------|----------|-------------|
| 1 | Firebase core + flavors | P0 | Project wiring | $0 |
| 2 | Firebase App Check | P0 | Protect AI Logic / Functions | $0 |
| 3 | Firebase AI Logic (Gemini text) | P1 | Standard engine, reviews, summaries | $0 (free tier) |
| 4 | Gemini Live API — Live Translate | P1 dev / P2 prod | Live engine | $0 (free tier) |
| 5 | ML Kit on-device translation | P1 | Offline engine | $0 |
| 6 | On-device ASR (whisper.cpp / sherpa-onnx) | P0–P1 | Speech → text | $0 |
| 7 | flutter_tts | P1 | Speak translations / quick phrases | $0 |
| 8 | Firebase Remote Config | P1 | Models, quotas, flags, capability matrix | $0 |
| 9 | Crashlytics + Analytics | P1 | Stability, product metrics | $0 |
| 10 | Firebase Auth (anonymous, Google, email link) + Firestore + Hosting | P2 | Sign-in, profile, sync, usage counters, deletion web page | $0 within free quota |
| 11 | Cloud Functions | P2 | `issueLiveToken`, `reportLiveUsage`, webhooks | needs Blaze plan |
| 12 | RevenueCat + Google Play Billing | P2 | Subscriptions, top-ups | $0 until $2.5k MTR |
| 13 | Android platform APIs | P1–P3 | Foreground service, overlay, playback capture | — |
| 14 | Google Play Console | P1–P2 | Testing tracks, release | $25 one-time |

---

## 1. Firebase core + flavors

- Two Firebase projects: `lingomate-dev` (Spark, never linked to billing) and `lingomate-prod` (Blaze from P2).
- Configure with FlutterFire CLI per flavor → `lib/app/firebase_options_dev.dart`, `firebase_options_prod.dart`; `android/app/src/{dev,prod}/google-services.json`.
- `main_dev.dart` / `main_prod.dart` call `bootstrap(Flavor.dev|prod)`.

**Why separate projects**: linking a billing account switches all Gemini Developer API usage in that project to pay-as-you-go. Keeping dev on Spark keeps dev free.

## 2. Firebase App Check

- Required: Firebase AI Logic is deactivated for projects without App Check enforcement (requirement effective 2 Nov 2026).
- Dev: debug provider; register the debug token printed in logcat in the console.
- Prod: Play Integrity provider. Enforce for AI Logic, Firestore, Functions.
- Failure mode: 403 `PERMISSION_DENIED` → show "Can't verify this app install" + retry; log to Crashlytics (no PII).

## 3. Firebase AI Logic — Gemini text (Standard engine)

- Package: `firebase_ai`. Provider: **Gemini Developer API** (`FirebaseAI.googleAI()`).
- Model name from Remote Config `model_text_translate` (default `gemini-2.5-flash-lite`).
- Sketch (verify exact API against current `firebase_ai` docs):

```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: remote.modelTextTranslate,
  systemInstruction: Content.system(TranslatorPrompt.system(from: from, to: to)),
  generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: 256),
);
final res = await model.generateContent([
  Content.text(TranslatorPrompt.user(context: last3, glossary: terms, text: source)),
]).timeout(const Duration(seconds: 6));
final translation = res.text?.trim();
```

- Translator system prompt (keep in `features/engines/translate/data/prompts.dart`):
  "You are a professional interpreter. Translate the user's utterance from {from} to {to}. Output only the translation. Keep names, numbers, units and code identifiers unchanged. Match the speaker's register. Use the glossary when a term appears. If the input is not in {from}, translate it to {to} anyway."
- Pricing reference (paid tier): `gemini-2.5-flash-lite` $0.10 / 1M input tokens, $0.40 / 1M output; free tier available. `gemini-3.1-flash-lite` $0.25 / $1.50.
- Limits: Firebase AI Logic per-user rate limit — default 100 requests/min/user (adjustable in Cloud console). Firebase AI Logic does **not** return `UsageMetadata`, so meter by audio seconds, not tokens.
- Free tier note: content may be used to improve Google products → never send real confidential audio/text in dev.

## 4. Gemini Live API — Live Translate (Live engine)

- Model: `gemini-3.5-live-translate-preview` (preview; no stability guarantee). 76 languages incl. Vietnamese; auto-detects input language.
- Transport: WebSocket `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent` (v1beta required for Live Translate with ephemeral tokens).
- Audio in: 16-bit mono PCM, 16 kHz, sent in 100 ms chunks. Audio out: 16-bit mono PCM, 24 kHz. Optional transcripts: `inputAudioTranscription`, `outputAudioTranscription`.
- Config: `translationConfig { targetLanguageCode, echoTargetLanguage }`. With `echoTargetLanguage=false` the model stays silent when input is already in the target language (default false).
- No tools, function calling or system instructions in Live Translate.
- Setup sketch (verify field placement against the Live Translate guide):

```json
{ "setup": {
    "model": "models/gemini-3.5-live-translate-preview",
    "generationConfig": { "responseModalities": ["AUDIO"] },
    "inputAudioTranscription": {},
    "outputAudioTranscription": {},
    "translationConfig": { "targetLanguageCode": "en", "echoTargetLanguage": false },
    "sessionResumption": {}
} }
```
  Audio frames: `{ "realtimeInput": { "audio": { "data": "<base64 pcm>", "mimeType": "audio/pcm;rate=16000" } } }`

- **Dev auth**: `?key=<GEMINI_API_KEY>` from `env/dev.json` (dev flavor only).
- **Prod auth**: ephemeral token from `issueLiveToken` (§11). Defaults: 1 min to open a session (`newSessionExpireTime`), 30 min to send messages (`expireTime`); we set `expireTime = now + blockSec`. Reconnect roughly every 10 min with `sessionResumption` (same token allowed within `expireTime`). Lock `translationConfig` in token constraints, or omit it and set `lock_additional_fields: []` to let the user pick the target. Raw-WebSocket parameter for the token: verify (OQ-10).
- Known limitations: voice can stick to one speaker in fast multi-speaker exchanges; language detection struggles with heavy accents / similar languages; background noise and music not fully filtered.
- Pricing (paid): $3.50 / 1M input tokens ($0.0053/min audio), $21.00 / 1M output ($0.0315/min); billed at 25 tokens per second of audio → ≈ $0.0368/min. Free tier available. Two sessions for two-way ≈ $0.042/min.
- Region availability: Gemini API is not offered in some countries (e.g. China, Russia, Iran, Belarus, Cuba, North Korea, Syria, Afghanistan, Myanmar, Hong Kong, Macau); requests from there fail with "User location is not supported" → handled in doc 03 §7.
- Fallback Live model (Firebase AI Logic Live API, Flutter supported): `gemini-3.1-flash-live-preview` — now labelled legacy; Google recommends `gemini-3.8-live` (verify price and Firebase support, OQ-5).

## 5. ML Kit on-device translation (Offline engine)

- Package: `google_mlkit_translation` (community plugin over Google's native API; Android minSdk 21; 64-bit only).
- 59 languages; same models as Google Translate offline mode; intended for casual/simple translation; non-English pairs pivot through English.
- Not supported (examples): Khmer, Lao, Burmese, Amharic, Nepali, Sinhala, Mongolian, Kazakh, Uzbek → `offlineTranslate:false` in capability matrix.
- Model management: `OnDeviceTranslatorModelManager` download/delete/isDownloaded; download on Wi-Fi by default (setting to allow mobile data). Close translators when session ends.
- Comply with ML Kit on-device translation usage/attribution guidelines (show attribution in About/Licenses and wherever required).

## 6. On-device ASR (chosen in spike — OQ-3)

Candidates (all behind `SpeechRecognizerEngine`):

| Candidate | Notes |
|-----------|-------|
| `transcribe_cpp` | Runs Whisper, Parakeet, Moonshine and 50+ open models, ~100 languages, Silero VAD and live text built in |
| `whisper_ggml` / `whisper_cpp_flutter_plus` | whisper.cpp 1.9.x; live transcription, Silero VAD; plus variant has on-device speaker-turn detection |
| sherpa-onnx based plugins | Streaming models available for some languages; Whisper ONNX export |

Spike criteria (doc 07 §5): Vietnamese + English WER on test set, latency per 5 s segment, RAM, model size, battery, stability over 30 min. Model sizes: start with multilingual `base`/`small` quantized; download on demand per language profile. Whisper is not truly streaming → VAD segmentation (doc 03 §5).

## 7. flutter_tts

- `getLanguages`, `isLanguageAvailable(lang)`, `setLanguage`, `setSpeechRate`, `awaitSpeakCompletion(true)`, completion/start handlers → drive `TtsState` for echo gating.
- Missing voice → open system TTS settings to install voice data.

## 8. Firebase Remote Config

- Keys listed in doc 03 §11. Defaults in `lib/core/config/remote_defaults.dart` (and `assets/capability_matrix.json`).
- Fetch on start (min fetch interval 1 h prod, 0 dev); activate on next cold start except `ff_*` flags (activate immediately at safe points).
- Parse JSON values defensively; on parse error keep defaults and report non-fatal to Crashlytics.

## 9. Crashlytics + Analytics

- Crashlytics: fatal + non-fatal; custom keys `engine`, `mode`, `pair` (no text).
- Analytics events: see doc 03 §12. Disable collection until consent where legally required (setting).

## 10. Firebase Auth + Firestore + Hosting (P2)

Flow and rules: doc 03 §17. Providers to enable in the console: Anonymous, Google, Email/Password with **Email link (passwordless)**.

**Google sign-in**
- Package `google_sign_in` ^7 — refactored around Android Credential Manager; `authenticate()` opens the system account picker, then build a Firebase credential with `GoogleAuthProvider.credential(idToken: …)` and call `linkWithCredential` (anonymous → Google).
- Don't use the legacy Google Sign-In for Android (`play-services-auth`); it is deprecated in favour of Credential Manager.
- Register SHA-1 and SHA-256 of debug, upload and Play app-signing keys in Firebase; re-download `google-services.json`.
- Use Google's official "Sign in with Google" button branding.

**Email link (passwordless)**
- Firebase Dynamic Links shut down on 25 Aug 2025; email-link sign-in now uses the project's Firebase Hosting domain (Android Auth SDK 23.2.0+ / BoM 33.9.0+).
- Android intent filter (`autoVerify`) for `https://<PROJECT_ID>.firebaseapp.com` (or custom Hosting domain) with `pathPrefix="/__/auth/links"`; set `linkDomain` in `ActionCodeSettings` when using a custom domain.
- Store the pending email locally to complete sign-in on the same device; ask for the email when the link opens elsewhere.

**Firestore**: schema & rules in doc 03 §9.2; rules tests with the emulator (doc 07). Free quota (Spark/Blaze): 50K reads/day, 20K writes/day, 1 GiB storage; Auth 50K MAU.

**Hosting**: privacy policy, terms and the account-deletion request page (`/delete-account`).

## 11. Cloud Functions (P2, Blaze)

Region: a Gemini-supported region close to users (e.g. `asia-southeast1`). If calls fail with "User location is not supported", switch region (known incidents with specific regions). API key in Secret Manager (`defineSecret('GEMINI_API_KEY')`).

| Function | Type | Purpose |
|----------|------|---------|
| `issueLiveToken` | callable (Auth + App Check required) | Quota check + reservation + ephemeral token(s) — algorithm in doc 03 §10 |
| `reportLiveUsage` | callable | Refund unused block seconds once per token |
| `revenuecatWebhook` | HTTPS (shared-secret header) | Update `users/{uid}.plan`, `planState`, `planExpiresAt`, top-up balance; append `transactions/{eventId}` (idempotent) |
| `deleteAccount` | callable (Auth + App Check + recent login) | Delete Firestore user data, live tokens, RevenueCat customer, then the Auth user (doc 03 §17.3) |
| `processDeletionRequest` | Firestore trigger / scheduled | Handle verified web deletion requests with the same routine |
| `cleanupLiveTokens` | scheduled daily | Close stale token records |

Sketch:

```ts
import { GoogleGenAI } from '@google/genai';
const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value(), httpOptions: { apiVersion: 'v1beta' } });
const expireTime = new Date(Date.now() + blockSec * 1000).toISOString();
const token = await ai.authTokens.create({ config: {
  uses: 1,
  expireTime,
  newSessionExpireTime: new Date(Date.now() + 60_000).toISOString(),
  liveConnectConstraints: {
    model: liveModel,
    config: { responseModalities: ['AUDIO'], sessionResumption: {},
              translationConfig: { targetLanguageCode: target, echoTargetLanguage: false } },
  },
}});
return token.name; // client uses it in place of the API key
```

Free quota: 2M invocations/month, 400K GB-s; then $0.40/million invocations.

## 12. RevenueCat + Google Play Billing (P2)

- `purchases_flutter`; `appUserID` = Firebase Auth uid.
- Entitlements: `pro_lite`, `pro`; consumable products for Live top-ups. Offerings/prices configured in Play Console + RevenueCat (pricing deferred, OQ-2).
- Webhook → `revenuecatWebhook` updates Firestore plan; client also reads entitlement from SDK for instant UI.
- Purchases require a signed-in account (D-18) so the `appUserID` is stable across devices; call `Purchases.logIn(uid)` after sign-in and `logOut()` on sign-out.
- Manage subscription screen (S-25) reads `CustomerInfo`:
  - `willRenew`, `unsubscribeDetectedAt` → cancelled-but-active state.
  - `billingIssueDetectedAt` → payment issue. During a Google Play grace period the entitlement stays active with this field set; it clears when payment recovers.
  - `expirationDate` → renew / until / grace-end dates.
  - `managementURL` → open with an `ACTION_VIEW` intent to reach Google Play subscription management (no native manage screen on Android). It is only valid after a purchase, so hide the action when null.
- Test renewals, grace period and account hold with Play license testers and test payment methods before release (doc 07 M-21).
- Costs: RevenueCat free up to $2,500 monthly tracked revenue, then 1%. Google Play takes 15% on auto-renewing subscriptions (10% service + 5% billing fee under the new structure).

## 13. Android platform APIs

| API | Phase | Notes |
|-----|-------|-------|
| Foreground service type `microphone` | P1 | Required for capture with screen off / app in background; persistent notification with Stop |
| `SYSTEM_ALERT_WINDOW` overlay | P1 | Floating captions in Meeting mode; graceful degrade if denied |
| `AudioRecord` / `record` package | P0 | 16 kHz mono PCM16 |
| `AudioTrack` (`PcmPlayer`) | P1 | Stream Live 24 kHz audio |
| `AudioPlaybackCapture` + `MediaProjection` | P3 | Only `USAGE_MEDIA`, `USAGE_GAME`, `USAGE_UNKNOWN`; call audio needs privileged `CAPTURE_VOICE_COMMUNICATION_OUTPUT` (system apps only) |
| Battery optimization exemption guide | P1 | Some OEMs kill FGS; link to instructions, don't request exemption by default |

## 14. Google Play Console

- $25 one-time registration.
- Personal accounts created after 13 Nov 2023: closed test with ≥ 12 testers opted in continuously for 14 days before applying for production. Organization accounts are exempt but need a D-U-N-S number (OQ-8).
- Tracks: internal (owner + friends, P1) → closed (≥ 12 testers × 14 days, P2) → production.
- Data safety form: microphone audio processed (not stored by default), transcripts stored on device, optional cloud sync, purchase history (RevenueCat), account info (email, name) when signed in.
- **Account deletion policy**: because users can create an account in the app, Play requires (a) an in-app path to delete the account and associated data and (b) a web link where users can request deletion; the data deletion questions in the Data safety form must be completed or app updates are rejected. → F-13, doc 03 §17.3.

## Reference links

- Firebase AI Logic Live API: https://firebase.google.com/docs/ai-logic/live-api
- Firebase AI Logic pricing: https://firebase.google.com/docs/ai-logic/pricing
- Firebase AI Logic quotas: https://firebase.google.com/docs/ai-logic/quotas
- Gemini Live Translate: https://ai.google.dev/gemini-api/docs/live-api/live-translate
- Gemini ephemeral tokens: https://ai.google.dev/gemini-api/docs/ephemeral-tokens
- Gemini API pricing: https://ai.google.dev/gemini-api/docs/pricing
- Gemini API available regions: https://ai.google.dev/gemini-api/docs/available-regions
- ML Kit translation: https://developers.google.com/ml-kit/language/translation
- ML Kit languages: https://developers.google.com/ml-kit/language/translation/translation-language-support
- google_mlkit_translation: https://pub.dev/packages/google_mlkit_translation
- Android playback capture: https://developer.android.com/media/platform/av-capture
- Firebase pricing: https://firebase.google.com/pricing
- RevenueCat pricing: https://www.revenuecat.com/pricing
- Play testing requirements: https://support.google.com/googleplay/android-developer/answer/14151465
- Play account deletion requirements: https://support.google.com/googleplay/android-developer/answer/13327111
- Firebase Auth — Google on Android: https://firebase.google.com/docs/auth/android/google-signin
- Firebase email link migration (Hosting domain): https://firebase.google.com/docs/auth/android/email-link-migration
- RevenueCat — manage/cancel subscription: https://revenuecat.github.io/codelabs/guides/show-manage-subscriptions.html
- RevenueCat — billing issues & grace period: https://revenuecat.github.io/codelabs/recover-involuntary-churn-billing-retry.html
