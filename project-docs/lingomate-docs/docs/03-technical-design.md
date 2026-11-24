# 03 — Technical Design

Status: Draft v0.1 · Applies to Phases 0–3 · Read with doc 04 (integrations)

## 1. Architecture overview

```
┌──────────────────────────── Flutter app (Android) ─────────────────────────────┐
│ Presentation  (screens, widgets, Riverpod Notifiers)                           │
│   Conversation · Listen · Meeting · Phrasebook · Quick phrases · Review ·      │
│   Settings · Paywall/Usage                                                      │
├────────────────────────────────────────────────────────────────────────────────┤
│ Application   (session controllers, EngineSelector, QuotaGuard, use cases)     │
├────────────────────────────────────────────────────────────────────────────────┤
│ Domain        (entities + engine interfaces, pure Dart)                        │
├────────────────────────────────────────────────────────────────────────────────┤
│ Data          (engine impls, repositories, Drift DAOs, Firebase clients)       │
│   WhisperAsr / SherpaAsr · MlKitTranslator · GeminiTextTranslator ·            │
│   GeminiLiveInterpreter · FlutterTtsSynth · Drift · Firestore · RemoteConfig   │
├────────────────────────────────────────────────────────────────────────────────┤
│ Platform (Kotlin, via MethodChannel/EventChannel)                              │
│   TranslationForegroundService · CaptionOverlay · PcmPlayer · (P3) Playback-   │
│   CaptureService                                                               │
└────────────────────────────────────────────────────────────────────────────────┘
          │ Firebase AI Logic (HTTPS)          │ Live API WebSocket (wss)
          ▼                                    ▼
   Gemini Flash-Lite (text)          Gemini Live Translate (speech↔speech)
          ▲                                    ▲ ephemeral token (P2+)
          │                         ┌──────────┴──────────┐
   App Check (Play Integrity)       │ Cloud Function       │──► Firestore usage
                                    │ issueLiveToken       │
                                    └──────────────────────┘
   Remote Config · Crashlytics · Analytics · (P2) Auth · Firestore · RevenueCat
```

Principles: offline-first; every engine replaceable; cost-bearing calls always pass through `QuotaGuard`; UI always shows the active engine.

## 2. Tech stack

| Concern | Choice | Notes |
|---------|--------|-------|
| Framework | Flutter stable, Dart 3 | Pin exact version in `.fvmrc` or CI |
| Android | minSdk 26; target/compile = latest stable | 64-bit ABIs only |
| State/DI | `flutter_riverpod` + `riverpod_annotation` (codegen) | Notifier/AsyncNotifier only, no StateNotifier |
| Routing | `go_router` | Typed routes |
| Models | `freezed`, `json_serializable` | |
| Local DB | `drift` + `sqlite3_flutter_libs` | Migrations versioned |
| Prefs | `shared_preferences` | Non-sensitive settings only |
| Firebase | `firebase_core`, `firebase_ai`, `firebase_app_check`, `firebase_remote_config`, `firebase_crashlytics`, `firebase_analytics`; P2: `firebase_auth`, `cloud_firestore`, `cloud_functions` | |
| Offline translate | `google_mlkit_translation` | 59 languages, English pivot |
| On-device ASR | Decided in spike (OQ-3): whisper.cpp wrapper (`whisper_ggml` / `whisper_cpp_flutter_plus`), `transcribe_cpp`, or sherpa-onnx | Behind `SpeechRecognizerEngine` |
| TTS | `flutter_tts` | Uses device engine |
| Mic capture | `record` (PCM16 stream) for P0/P1; move to native `AudioRecord` in the foreground service if needed | 16 kHz mono PCM16 |
| Live transport | `web_socket_channel` | JSON frames, base64 audio |
| PCM playback | Native `AudioTrack` via platform channel (`PcmPlayer`) | 24 kHz mono PCM16 from Live |
| Background | Native foreground service (type `microphone`); evaluate `flutter_foreground_task` in spike | |
| Overlay | Native overlay window (`SYSTEM_ALERT_WINDOW`); evaluate `flutter_overlay_window` in spike | |
| Subscriptions (P2) | `purchases_flutter` (RevenueCat) | |
| Lints | `very_good_analysis` or `flutter_lints` + strict analysis options | |
| Localization | `flutter_localizations` + `intl`, gen-l10n (`l10n.yaml`: `template-arb-file: app_en.arb`) | English default/fallback (D-22); Android 13+ per-app language via `res/xml/locales_config.xml` |
| Icons | `flutter_svg` (in-app icons from `assets/icons`), `flutter_launcher_icons` (dev dependency, per-flavor configs) | Notification icon `@drawable/ic_stat_lingomate` |

## 3. Repository layout

```
/
├─ CLAUDE.md
├─ docs/
├─ design/                    # screen PNG/HTML exports of the Figma design (see design/README.md)
├─ env/                       # gitignored except *.example.json
│  ├─ dev.example.json
│  └─ dev.json                # GEMINI_API_KEY (dev only), flags
├─ lib/
│  ├─ main_dev.dart
│  ├─ main_prod.dart
│  ├─ app/                    # bootstrap, router, theme, l10n wiring, flavors
│  ├─ core/
│  │  ├─ audio/               # capture, VAD, segmenter, ring buffer, PcmPlayer client
│  │  ├─ config/              # RemoteConfig service + remote_defaults.dart
│  │  ├─ capability/          # CapabilityMatrix model + provider
│  │  ├─ connectivity/        # online/offline + cloud availability (region) state
│  │  ├─ quota/               # QuotaGuard, window math, local usage store
│  │  ├─ errors/              # Failure types, error mapper
│  │  ├─ analytics/           # event wrappers (no PII)
│  │  └─ utils/
│  ├─ features/
│  │  ├─ onboarding/
│  │  ├─ engines/             # asr/, translate/, tts/, live/, selector/
│  │  ├─ conversation/
│  │  ├─ listen/
│  │  ├─ meeting/
│  │  ├─ sessions/            # history + transcript viewer
│  │  ├─ phrasebook/
│  │  ├─ quick_phrases/
│  │  ├─ language_packs/
│  │  ├─ review/              # SRS (P2)
│  │  ├─ learning/            # post-session review, roleplay (P2/P3)
│  │  ├─ glossary/            # (P2)
│  │  ├─ account/             # (P2) sign-in (S-24), Me/profile (S-17), account details, sign-out, delete account
│  │  ├─ usage/               # usage meters (P2)
│  │  ├─ subscription/        # (P2) paywall (S-19), manage subscription (S-25), top-ups, purchase history
│  │  ├─ settings/
│  │  └─ devtools/            # dev flavor only: engine switcher, latency HUD, benchmark runner
│  └─ l10n/                   # app_en.arb (template, English source), app_vi.arb; partner_strings.dart (wave-1 partner-facing strings)
├─ assets/
│  ├─ brand/                  # app icon layers (SVG + PNG), Play icon, notification icon — see assets/brand/README.md
│  ├─ icons/                  # 79 in-app SVG icons (24 dp, 2 dp stroke) — see assets/icons/README.md
│  ├─ quick_phrases/          # situation packs (JSON)
│  └─ capability_matrix.json  # default matrix (overridden by Remote Config)
├─ android/app/src/main/kotlin/<pkg>/
│  ├─ TranslationForegroundService.kt
│  ├─ CaptionOverlayService.kt
│  ├─ PcmPlayer.kt
│  ├─ PlaybackCaptureService.kt   # P3
│  └─ channels/
├─ functions/                 # P2: TypeScript Cloud Functions
├─ test/                      # unit + widget + golden
├─ integration_test/
└─ test_assets/audio/         # benchmark clips + reference transcripts (gitignored if large; see doc 07)
```

Feature folder convention: `features/<name>/{presentation,application,domain,data}/`.

## 4. Core abstractions (domain)

```dart
enum EngineKind { offline, standard, live }
enum Speaker { a, b }

class LanguagePair { final String a; final String b; } // BCP-47, e.g. 'vi', 'en'

/// Streaming or segment-based speech recognition (on-device).
abstract interface class SpeechRecognizerEngine {
  Future<void> ensureReady(String lang);                 // model present & loaded
  Stream<AsrResult> transcribe(Stream<AudioSegment> segments, {String? hintLang, String? prompt});
  Future<String?> detectLanguage(AudioSegment segment, {required List<String> candidates});
}

/// Text translation (ML Kit offline, Gemini online).
abstract interface class TextTranslatorEngine {
  EngineKind get kind;
  Future<bool> isAvailable(String from, String to);
  Future<Translation> translate(TranslateRequest req);    // includes context + glossary
}

abstract interface class SpeechSynthesizerEngine {
  Future<bool> supports(String lang);
  Future<void> speak(String text, {required String lang, double rate = 1.0});
  Future<void> stop();
  Stream<TtsState> get state;                             // used for echo gating
}

/// Speech-to-speech interpreter (Gemini Live Translate).
abstract interface class LiveInterpreterEngine {
  Future<LiveSession> open(LiveSessionConfig config);     // target lang, echo flag, credentials
}

abstract interface class LiveSession {
  void sendAudio(Uint8List pcm16k100ms);
  Stream<LiveEvent> get events; // inputTranscript, outputTranscript, outputAudio(pcm24k), goAway, error, closed
  Future<void> close();
}
```

`AudioSegment` = PCM16 16 kHz mono bytes + start/end timestamps + VAD confidence.

## 5. Audio pipeline

1. **Capture**: 16 kHz, mono, PCM16, 20 ms frames. Source `VOICE_RECOGNITION` (Conversation/Listen); `MIC` with noise suppression off for Meeting (laptop speaker is far-field). Enable `NoiseSuppressor`/`AutomaticGainControl` where available; make it a devtools toggle for the spike.
2. **VAD**: Silero VAD (bundled with the chosen ASR lib) — speech start/end with `silenceMs = 600`, `minSpeechMs = 400`, `maxUtteranceMs = 15000` (force-cut long monologues at the nearest pause > 250 ms).
3. **Segmenter** emits `AudioSegment`s to the active pipeline (Offline/Standard). Live mode streams raw 100 ms chunks instead.
4. **Echo gating** (critical): when TTS or Live audio is playing through the speaker, the mic will hear it.
   - Default: half-duplex — pause segment emission while `TtsState.speaking` (+150 ms tail).
   - Live mode on speaker: half-duplex gating too; recommend headphones (UI hint). Spike evaluates `VOICE_COMMUNICATION` source + `AcousticEchoCanceler` as full-duplex option.
5. **Playback**: TTS via `flutter_tts`; Live audio (24 kHz PCM16) via native `PcmPlayer` (AudioTrack, streaming mode, low-latency).
6. **Ring buffer**: keep last 30 s of audio in memory only (for "replay last sentence" and ASR re-tries). Never written to disk.

## 6. Pipelines

### 6.1 Offline (P1)
`mic → VAD → segment → ASR(on-device, lang hint) → ML Kit translate → UI (+ TTS in Conversation)`
- Language of a segment: in Conversation, speaker side is known (A/B buttons or auto-detect with candidates [a,b]); in Listen/Meeting, source language fixed by user.
- ML Kit pivots through English for non-English pairs (quality note shown in language picker).

### 6.2 Standard (P1)
`mic → VAD → segment → ASR(on-device) → GeminiTextTranslator (Firebase AI Logic) → UI (+ TTS)`
- Request = system instruction (translator role, output only the translation, keep names/numbers, register), last 3 utterances as context, glossary terms (P2), source text.
- Model from Remote Config `model_text_translate` (default `gemini-2.5-flash-lite`).
- Timeout 6 s → retry once → fall back to Offline for that utterance if pair supported (mark utterance `engine=offline_fallback`).
- Usage counted as utterance audio duration (seconds) into the Standard meter.

### 6.3 Live (P1 dev-only, P2 production)
`mic 100 ms PCM chunks → WebSocket (BidiGenerateContent) → inputTranscript + outputTranscript + 24 kHz audio`
- Setup message: model `model_live_translate`, `responseModalities: [AUDIO]`, `inputAudioTranscription: {}`, `outputAudioTranscription: {}`, `translationConfig: { targetLanguageCode, echoTargetLanguage: false }`.
- **Two-way conversation**: open two sessions on the same mic stream — session A targets lang A, session B targets lang B. With `echoTargetLanguage=false` each session stays silent when input is already in its target language. Validate in spike (OQ-4); fallback = Standard engine with TTS.
- **Connection lifetime**: reconnect about every 10 minutes using session resumption; on `goAway` reconnect transparently.
- **Credentials**: dev = API key from `env/dev.json` (dev flavor only); prod = ephemeral token from `issueLiveToken` (single use, short expiry ≤ quota block). Token expiry ends the session; client requests a new token (quota checked again).
- Show both transcripts; play translated audio; mute translated audio option (captions only still costs output tokens — prefer Standard for captions-only use).

### 6.4 Meeting mode specifics (P1)
- Runs inside `TranslationForegroundService` (type `microphone`, persistent notification with Stop action) so it survives screen-off/app switch.
- Captions rendered in `CaptionOverlay` (draggable bubble, 2–3 last lines, tap to expand, long-press to save phrase). Requires `SYSTEM_ALERT_WINDOW` permission flow.
- Default engine Standard (cheap, text). Live allowed when user explicitly enables it.

### 6.5 Media capture (P3)
- `MediaProjection` consent + `AudioPlaybackCaptureConfiguration` matching `USAGE_MEDIA`, `USAGE_GAME`, `USAGE_UNKNOWN`. Call audio cannot be captured. Apps that opt out of capture produce silence → detect and explain.

## 7. Engine selection & fallback

```
select(mode, pair, prefs, state):
  candidates = prefs.engineOrder  // default [standard, offline]; live only if user enabled & plan allows
  for e in candidates:
    if !capability.supports(e, pair, mode): continue
    if e != offline && (!state.online || state.cloudBlockedForRegion): continue
    if e == live && !quota.canStartLive(): continue
    if e == standard && !quota.canUseStandard(): continue
    if e == offline && !packs.installed(pair): continue
    return Selected(e, reason)
  return NoEngine(reason)   // UI: explain + action (download pack / go online / upgrade)
```
- Re-evaluated on: connectivity change, quota event, error burst (3 consecutive failures in 30 s), user override.
- Mid-session switch shows a non-blocking toast "Switched to Offline — no internet" and an engine chip change.
- **Region block**: error `FAILED_PRECONDITION` with "User location is not supported" → set `cloudBlockedForRegion=true` for 24 h, banner "Cloud translation isn't available in your current region. Offline still works."

## 8. Capability matrix

Remote Config key `capability_matrix` (JSON), default in `assets/capability_matrix.json`:

```json
{
  "version": 3,
  "languages": {
    "vi": { "name": "Tiếng Việt", "offlineTranslate": true, "asrOnDevice": "good", "live": true, "wave": 1 },
    "en": { "name": "English",    "offlineTranslate": true, "asrOnDevice": "good", "live": true, "wave": 1 },
    "km": { "name": "ខ្មែរ",        "offlineTranslate": false, "asrOnDevice": "poor", "live": true, "wave": 3 }
  }
}
```
- `asrOnDevice`: `good | fair | poor | none` (set from spike measurements). `poor`/`none` → Standard/Offline disabled for that language; Live only.
- TTS support checked at runtime (`flutter_tts.getLanguages`); missing voice → prompt to install voice data, captions still work.
- Wave-1: en, vi, ja, ko, zh, th, id, es, fr, de (supported by both ML Kit and Live Translate).

## 9. Data model

### 9.1 Local (Drift)

| Table | Columns (key ones) |
|-------|--------------------|
| `sessions` | id (uuid), mode, engine_initial, lang_a, lang_b, started_at, ended_at, title, duration_sec, live_sec, standard_sec |
| `utterances` | id, session_id → sessions, speaker (a/b/null), source_lang, source_text, target_lang, target_text, start_ms, end_ms, engine, latency_ms, is_saved |
| `phrases` | id, source_lang, source_text, target_lang, target_text, note, situation_key?, from_utterance_id?, favorite, created_at, updated_at, deleted_at (soft delete for sync) |
| `tags` / `phrase_tags` | id, name / phrase_id, tag_id |
| `srs_cards` (P2) | id, phrase_id, direction (src→tgt / tgt→src), ease (2.5), interval_days, reps, lapses, due_at, last_reviewed_at |
| `quick_phrase_favorites` | phrase_key, lang_pair, created_at |
| `glossary_sets` / `glossary_terms` (P2) | id, name / id, set_id, term, translation, note |
| `language_packs` | lang, asr_model_id, asr_bytes, mlkit_downloaded, status, updated_at |
| `usage_ledger` | id, engine, seconds, at, session_id, synced (bool) |

Indices: `utterances(session_id, start_ms)`, `phrases(source_lang, target_lang)`, `srs_cards(due_at)`. Full-text search on phrases/utterances via FTS5 virtual tables.

### 9.2 Cloud (Firestore, P2)

```
users/{uid}
  plan: 'free' | 'pro_lite' | 'pro' ...      (written by RevenueCat webhook function)
  planState: 'active' | 'cancelled' | 'billing_issue' | 'expired'   (webhook)
  planExpiresAt, liveTopupSec                  (webhook)
  displayName, photoUrl, email, provider       (client, from Auth; editable displayName)
  myLanguages: ['vi','en','ja'], uiLocale
  stats: { translatedSec, phrasesSaved, streakDays }   (client, merged max-wins)
  createdAt, lastActiveAt
users/{uid}/transactions/{eventId}   { type: 'subscription'|'renewal'|'topup'|'refund', productId, at, price, currency }  // webhook only
deletionRequests/{id}                 { email, uid?, requestedAt, source: 'app'|'web', status }                           // web form + functions
users/{uid}/usage/live        { windowStart, windowUsedSec, weekStart, weekUsedSec, updatedAt }   // server-only writes
users/{uid}/usage/standard    { same shape }                                                      // client increments only
users/{uid}/phrases/{id}      mirror of local phrases (sync opt-in)
users/{uid}/srs/{id}
users/{uid}/glossary/{setId}/terms/{id}
liveTokens/{tokenId}          { uid, issuedAt, blockSec, refundedSec, closedAt }                   // server-only
```
Security rules: user can read own docs; `usage/live`, `liveTokens`, `transactions`, `deletionRequests` and the fields `plan`, `planState`, `planExpiresAt`, `liveTopupSec` writable only by Functions (admin SDK); profile fields (`displayName`, `myLanguages`, `uiLocale`, `stats`) writable by the owner; `usage/standard` client may only increment `windowUsedSec`/`weekUsedSec` by ≤ 600 per write and only move window starts forward.

## 10. Quota engine

Windows (per engine): **5-hour window** starts at first use when no active window (or previous expired) and resets 5 h after start; **weekly window** starts at first use and resets 7 days after start. A request is allowed if both windows have remaining time.

```ts
remaining = min(win5hLimit - win5hUsed, weekLimit - weekUsed)   // seconds
resetAt   = earliest reset among windows that are exhausted
```

**Live (server-enforced, P2)** — callable `issueLiveToken({ targetLangs[], mode })`:
1. Verify Auth + App Check. **Reject anonymous users** (`sign_in_provider == 'anonymous'`) with `{ allowed:false, reason:'sign_in_required' }` — Live, including the free trial, needs a real account so reinstalling can't reset the trial (D-18). Load plan limits (Remote Config server template or a config doc).
2. Transaction on `usage/live`: roll windows if expired; compute `remaining`.
3. If `remaining < 60 s` → return `{ allowed: false, resetAt, reason }`.
4. `blockSec = min(600, remaining)`; add `blockSec` to both used counters (reservation); create `liveTokens/{id}`.
5. Create ephemeral token(s) (one per session; two for two-way): `uses: 1`, `expireTime = now + blockSec`, `newSessionExpireTime = now + 60 s`, locked `liveConnectConstraints` (model + translationConfig as requested).
6. Return `{ tokens, blockSec, expiresAt, remainingAfter }`.

`reportLiveUsage({ tokenId, usedSec })` on clean session end refunds `blockSec - usedSec` (clamped ≥ 0, once per token). If never called, the full block stays charged (fail-safe for us).

**Standard (client-enforced)**: `QuotaGuard` checks local mirror before each utterance; writes `usage_ledger`; syncs increments to `usage/standard` every 60 s and on session end. Firebase AI Logic per-user RPM limit is the server-side safety net.

**Offline**: never metered.

Limits come from Remote Config `quota_limits`:
```json
{ "free":     { "standard": { "win5hSec": 1800,  "weekSec": 3600  }, "live": { "trialSec": 600 } },
  "pro":      { "standard": { "win5hSec": 10800, "weekSec": 36000 }, "live": { "monthSec": 1800 } } }
```
(Values are placeholders — pricing is deferred, OQ-2. Support both window-based and monthly allowances plus prepaid top-up balance `live.topupSec`.)

UI: usage sheet shows per-engine bars "This 5-hour window: 12/30 min · resets 14:30" and "This week: 2.1/6 h · resets Mon 09:12".

## 11. Remote Config keys

| Key | Type | Default |
|-----|------|---------|
| `model_text_translate` | string | `gemini-2.5-flash-lite` |
| `model_text_review` | string | `gemini-2.5-flash-lite` |
| `model_live_translate` | string | `gemini-3.5-live-translate-preview` |
| `model_live_fallback` | string | `gemini-3.1-flash-live-preview` (re-evaluate, OQ-5) |
| `capability_matrix` | json | asset default |
| `quota_limits` | json | see §10 |
| `live_block_sec` | int | 600 |
| `ff_live_enabled` | bool | false (prod), true (dev) |
| `ff_meeting_overlay` | bool | true |
| `ff_post_session_review` | bool | false |
| `ff_paywall` | bool | false |
| `min_supported_build` | int | 1 (force-update gate) |
| `ff_email_link_signin` | bool | true |
| `ff_manage_subscription` | bool | false (on with paywall) |

## 12. Security & privacy

- App Check enforced for Firebase AI Logic (required since 2 Nov 2026): Debug provider in dev, Play Integrity in prod.
- Account deletion requires recent authentication (re-auth with the same provider) and App Check; `deleteAccount` is idempotent.
- No API keys in prod. Dev key restricted (Android app restriction + Generative Language API only) and only in dev flavor.
- Audio: memory only (ring buffer ≤ 30 s). Transcripts: local DB; "Delete all data" wipes DB + prefs + cloud copies.
- Listening indicator: persistent notification + in-app pulsing mic chip whenever capture is on.
- First-use consent sheet for Meeting/Listen: "Tell people you're translating the conversation."
- Analytics events carry no text: `session_start{mode,engine,pair}`, `session_end{duration,live_sec,standard_sec,fallbacks}`, `engine_switch{from,to,reason}`, `latency_bucket`, `phrase_saved{source}`.
- Production uses Gemini paid tier (free-tier content may be used to improve Google products).

## 13. Errors & resilience

| Failure | Detection | Behaviour |
|---------|-----------|-----------|
| No network | connectivity + request errors | Switch to Offline if pack installed; else banner + "Download pack" CTA |
| Region not supported | `FAILED_PRECONDITION` "User location is not supported" | Cloud off 24 h; Offline only; banner |
| Quota exhausted | QuotaGuard / function `allowed:false` | Stop cloud engine at utterance boundary; show usage sheet with reset time + upgrade/top-up (P2) |
| Live socket drop | close code / goAway | Reconnect with resumption ≤ 2 tries, then fall back to Standard |
| ASR model missing/corrupt | load error | Prompt re-download; Standard/Live unaffected if online |
| Mic permission denied | permission API | Explain + deep link to settings |
| Overlay permission denied | `canDrawOverlays` false | Meeting runs with in-app captions only |
| FGS killed by OEM | service onDestroy without stop | Notify user; link to battery-optimization guide |
| Translation timeout | 6 s | Retry once, then Offline for that utterance |

## 14. Performance budgets (reference device)

| Item | Budget |
|------|--------|
| Cold start to Home | ≤ 2.0 s |
| Mic tap → listening | ≤ 300 ms |
| Standard: end of utterance → caption | p50 ≤ 2.5 s, p90 ≤ 4 s |
| Offline: end of utterance → caption | p50 ≤ 3 s |
| Live: speaker → translated audio | ≤ 3 s typical |
| RAM during session | ≤ 600 MB incl. ASR model |
| Battery, 30-min Meeting (Standard) | ≤ 8% |
| APK (without models) | ≤ 60 MB; models downloaded on demand |

## 15. Build flavors, environments, CI

| Flavor | Firebase project | Plan | Live credentials | Devtools |
|--------|------------------|------|------------------|----------|
| `dev` | `lingomate-dev` | Spark ($0) | API key via `--dart-define-from-file=env/dev.json` | Enabled |
| `prod` | `lingomate-prod` | Blaze (from P2) | Ephemeral token from `issueLiveToken` | Disabled |

CI (GitHub Actions): `flutter analyze`, `flutter test`, build `prod` release APK, **secret scan** (fail if `AIza` or `env/dev.json` content appears in the release artifact), functions lint/test (P2).

## 16. Android manifest essentials

Permissions: `RECORD_AUDIO`, `INTERNET`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`, `SYSTEM_ALERT_WINDOW` (Meeting), P3: `FOREGROUND_SERVICE_MEDIA_PROJECTION`.
Application: `android:localeConfig="@xml/locales_config"` listing `en`, `vi` (update with every new UI language).
Service: `<service android:name=".TranslationForegroundService" android:foregroundServiceType="microphone" android:exported="false"/>`.
Request runtime permissions just-in-time with an explainer screen first.

## 17. Accounts & subscriptions (P2)

### 17.1 Identity model
- Every install starts with **Firebase anonymous auth** (silent). Local-only features never need more.
- Upgrade paths (S-24): Google via `google_sign_in` ^7 (Credential Manager) → `GoogleAuthProvider.credential(idToken)`; email link via `sendSignInLinkToEmail` with Firebase Hosting link domain. Both use `currentUser.linkWithCredential` so the uid stays the same.
- `credential-already-in-use` → sign in with that credential instead, then run **merge**: upload this device's local phrases/tags/SRS into the existing account (dedupe by source text + pair), then switch the local DB to the signed-in uid.
- `AuthGate` provider exposes `AuthState { anonymous | signedIn(provider) }`; features ask `requireSignIn(reason)` which opens S-24 and resumes the original action after success.
- Sign-in required for: Live (any), purchase/restore, enabling sync. Not required for: Offline, Standard (free quota), quick phrases, local phrasebook.

### 17.2 Sign out & local data
- Sign out → dialog Keep / Remove device data → `signOut()` → new anonymous session.
- Local DB rows carry `owner_uid`; "Keep" re-assigns them to the new anonymous uid; "Remove" deletes them.

### 17.3 Account deletion (Play policy)
- Callable `deleteAccount` (Auth + App Check + recent login): recursive delete `users/{uid}`, delete `liveTokens` where uid, delete RevenueCat customer via REST API (verify endpoint), delete Auth user last. Client then wipes Drift DB, prefs and (optional) models, returns to onboarding.
- Web page (Firebase Hosting, `/delete-account`): form → `deletionRequests` → owner verifies the email (link) → same deletion routine. Linked from Data safety, privacy policy and Me → Privacy & data.
- Active Google Play subscriptions are **not** cancelled by deletion; the confirmation screen says so and links to Play.

### 17.4 Subscription state
- Source of truth on device: RevenueCat `CustomerInfo` (listener → `SubscriptionState` provider). Mapping:
  - no active entitlement → `free` (or `expired` if a billing issue preceded it)
  - active + `billingIssueDetectedAt != null` → `billingIssue(graceUntil = expirationDate)`
  - active + `willRenew == false` (or `unsubscribeDetectedAt != null`) → `cancelled(until = expirationDate)`
  - active + `willRenew == true` → `active(renewsOn = expirationDate)`
- Server side: webhook mirrors `plan`, `planState`, `planExpiresAt`, `liveTopupSec` into `users/{uid}` and appends `transactions` (idempotent on event id). Quotas read the plan from Firestore, never from the client.
- "Cancel or change payment" opens `customerInfo.managementURL` with an `ACTION_VIEW` intent (hidden when null).
