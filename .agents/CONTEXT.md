---
trigger: always_on
description: Repository context for agentic AI
globs: 
---

# Repository Context

## Overview

This document describes the architectural patterns, folder structure, and coding standards for the Flutter application. Use this context when adding new features to ensure consistency.

## High-Level Architecture

The application follows a **Feature-First Architecture** combined with separated layers for State Management, UI, and Repositories.

- **State Management**: Uses **Riverpod** with `Notifier` and `NotifierProvider`. State classes are managed with `Equatable`.
- **Dependency Injection**: Uses **GetIt** and **Injectable** for Repositories and Services.
- **Routing**: Uses **GoRouter** with Riverpod providers.
- **Networking**: Uses **Dio** and **Retrofit** for API calls. API responses are wrapped in a generic `Result` (`Success`/`Failed`).
- **Data Models**: Employs `Equatable` for models and states.
- **UI**: Flutter 3.50 with Material and Cupertino from the `material_ui` and `cupertino_ui` packages. Screens use the shared `AppPlatform*` widgets in `lib/common/widgets`, which pick the Material or the Cupertino widget from `context.isCupertino`.
- **Styling**: Colours come from `assets/color/values/colors.xml` (generated into `ColorName`, also an Android resource; holds the doc 08 §2.1 tokens) and the light/dark `ColorScheme` in `AppTheme` (paper = `surface`, surface = `surfaceContainerLowest`, surfaceAlt = `surfaceContainerHigh`, ink = `onSurface`, inkMuted = `onSurfaceVariant`, line = `outlineVariant`, brand = `primary`, brandSoft = `primaryContainer`, partner half = `inverseSurface`/`onInverseSurface`, danger = `error`); roles with no Material slot (engine chips, success, warning, listening, billing banner) come from `context.appColors` (`AppColors` theme extension); text styles from `PlatFormThemeDataExtension`; shared sizes from `AppParams`; sizes are scaled with `flutter_screenutil`.

## Project Structure

```
lib/
├── common/             # Reusable widgets, enums, extensions, utils, exceptions
│   ├── extensions/     # BuildContext, platform (isCupertino), text style and language name (AppLocalizations.languageName) extensions
│   ├── resources/      # AppTheme, AppParams, Dimens, AppConfiguration
│   └── widgets/        # Shared AppPlatform* widgets; AppIcon + AppIcons enum over the 79 SVGs in assets/icons; EngineChip (engine colour/icon/label, Live on-air dot honouring reduce motion); showAppPlatformDialog (two-choice Material/Cupertino dialog); MicButton (idle/listening ring/processing/speaking/disabled); AppBanner (info/warning/error + action); showAppToast (3 s overlay toast); AppCircleIconButton (round AppIcon button); showEngineSheet (engines with block reasons, returns the pin, AC-05.7); showAppActionSheet (bottom list of AppSheetAction); AppSearchField; showAppTextInputDialog; AppSelectableChip (multi-select pill with badges); SettingsRow; showExplainerSheet (S-03 style sheet); ensureMicAccess (mic_permission_gate.dart: explainer before the system prompt, Open settings after two refusals, AC-01.6/01.7); AppLanguageButton + showAppLanguageSheet (F-11); AppSegmentedControl; AppTextField; saveToPhrasebook (save_phrase_action.dart: save + Saved/Already toast); showAppToast takes an optional action (Undo, 5 s); EngineBadge (pill in an engine's colours, AppColors.engine(kind)); speakOrShow / openShowMode (speak_or_show.dart: TTS when a voice is installed, else show mode with the install-voice hint, AC-09.2); QuickPhraseCard + QuickFavoritesRow (favourite quick phrases for a pair, used by Phrases → Quick and Home); SettingsSwitchRow / SettingsChoiceRow / SettingsSectionHeader (settings_toggle_rows.dart); showAppPlatformOptionDialog (two choices plus a checkbox); showAppLicensePage; CaptionScale (multiplies the text scale by the caption size setting; wraps conversation captions and transcript lines); KeepScreenOn (keeps the screen awake while shown when the setting is on, via SystemSettings.keepScreenOn); saveToPhrasebook takes a `source` for the phrase_saved event
├── core/               # Core configuration, Dependency Injection, Networking, Storage
│   ├── background/     # BackgroundCapture: TranslationForegroundService (microphone FGS, Stop/Open notification) + CaptionOverlay over channels lingomate/background(+/events)
│   ├── ai/             # GenerativeModelFactory: Gemini models via Firebase AI Logic, model names from Remote Config
│   ├── api/            # Retrofit Clients, API Models (Request Body, Responses)
│   ├── audio/          # AudioPipeline: capture (record, 16 kHz PCM16) → 20 ms frames → 30 s ring buffer → EchoGate → VAD → Segmenter → AudioSegment; 100 ms chunks for Live; LatencyTimeline
│   ├── config/         # remote_defaults.dart (keys + defaults, the only place model names live); RemoteConfigService (typed getters, incl. asr_models: speech model download per language)
│   ├── data/           # Base data models (e.g., Result wrapper)
│   ├── database/       # Drift AppDatabase and tables (sessions, utterances, phrases, tags, quick phrase favorites, language packs, usage ledger); schema 2 adds the utterances_fts FTS5 index (unicode61, accents removed) kept in sync by triggers
│   ├── analytics/      # AnalyticsService (firebase_analytics behind AnalyticsSink; events without text: session_start, session_end, engine_switch, phrase_saved; nothing is sent while consent is off, AC-10.4), analyticsProvider, crashReporterProvider, privacyConsentProvider (applies the analytics and crash consent; watched by MyApp)
│   ├── licenses/       # registerAppLicenses(): ML Kit, sherpa-onnx, whisper.cpp and Silero attributions added to LicenseRegistry at start-up (AC-10.5)
│   ├── quick_phrases/  # T-1.10 F-09: QuickPhraseCatalog loaded from assets/quick_phrases/<situation>.json (8 situations, ≥ 20 phrases, wave-1 languages, optional {slot} with values), quickPhraseCatalogProvider; quickSourceProvider (own language), quickTargetProvider ("Translate into", defaults to the partner); QuickPhraseFavorites + quickFavoriteKeysProvider(pair) over quick_phrase_favorites (per source-target pair)
│   ├── phrases/        # PhraseRepository (phraseRepositoryProvider): save with de-dup on source text + pair (marks the utterance saved), watch(PhraseFilter: pair either direction, tag, favourites, FTS query), watchOne, watchPairs, watchTags, watchCount, edit, setFavorite, addTag/removeTag, softDelete/restore; schema 3 adds the phrases_fts FTS5 index
│   ├── sessions/       # SessionRepository (sessionRepositoryProvider, appDatabaseProvider): start/addUtterance/finish (auto title, duration, metered seconds; empty sessions dropped), watchSessions, load, FTS search, rename, delete, plainText for sharing; UtteranceEngine stores offline/standard/live/offline_fallback/none
│   ├── di/             # GetIt & Injectable setup
│   ├── engines/        # EngineKind and the SpeechRecognizerEngine / TextTranslatorEngine interfaces (doc 03 §4); engine_instances.dart holds the shared providers (audioCaptureProvider, asrModelCatalogProvider, speechRecognizerProvider, textTranslatorProvider(kind), vadFactoryProvider, speechSynthesizerProvider) used by modes and devtools
│   │   ├── asr/        # T-0.4 spike: AsrModelStore (models/ folder), SherpaWhisperEngine (worker isolate), WhisperCppEngine; both detect the language with Whisper's auto mode for detectLanguage
│   │   ├── live/       # T-0.5 spike: LiveCodec (setup/audio/server messages, doc 04 §4), LiveSession (WebSocket, goAway → resume with handle)
│   │   ├── tts/        # SpeechSynthesizerEngine + FlutterTtsSynthesizer (speak completes when playback ends)
│   │   ├── translate/  # TranslatorPrompt, GeminiTextTranslator (Standard, AI Logic, 6 s timeout + 1 retry), MlKitTextTranslator (Offline)
│   │   └── selection/  # CapabilityMatrix (+ loader: Remote Config override or assets/capability_matrix.json), EngineSelector (doc 03 §7, reasons per engine), ErrorBurstTracker, RegionBlock; engine_providers.dart wires onlineProvider (connectivity_plus), capabilityMatrixProvider, liveAvailableProvider (dev flavor + ff_live_enabled, AC-05.6), enginePinProvider (session pin, also set by devtools), regionBlockProvider (saved 24 h block), errorBurstProvider, packsInstalledProvider into engineSelectionProvider(EngineRequest)
│   ├── errors/         # CrashReporter: Crashlytics fatal/non-fatal reports and engine/mode/pair keys, never transcript text
│   ├── settings/       # UserSettings + userSettingsProvider (sync, shared prefs via sharedPreferencesProvider): onboardingDone, appLocale (null = phone), myLanguage, partnerLanguages, pair (pairA/pairB), micDenials; AppPreferences + appPreferencesProvider (app_preferences.dart, F-10): engine preference Auto / Prefer Offline / Prefer Standard → EngineSelectionInput.engineOrder, allow Live (dev), voice speed → RatedSpeechSynthesizer in speechSynthesizerProvider, caption size, keep screen on, analytics and crash consent
│   ├── platform/       # MicPermission (permission_handler: status/request) and SystemSettings over channel lingomate/system_settings (SystemSettingsChannel.kt): opens the TTS voice installer, the app's settings page and the share sheet (shareText), and keeps the screen on (keepScreenOn → FLAG_KEEP_SCREEN_ON in MainActivity)
│   ├── firebase/       # bootstrapFirebase: Firebase.initializeApp + App Check (debug provider in dev, Play Integrity otherwise)
│   ├── dio/            # Dio interceptors and configurations
│   └── storage/        # Local storage (Shared Preferences, Secure Storage)
├── features/           # Feature folders
│   ├── onboarding/     # T-1.4 F-01: WelcomePage S-01 (value props, privacy, app language), SetupPage S-02 (I speak with search, I talk with chips + Offline/Live badges, pack offer with sizes → Download/Later); OnboardingNotifier saves via userSettingsProvider and starts packs through languagePacksProvider (cross-feature: language_packs data)
│   ├── home/           # HomeShell (StatefulShellRoute, 4 tabs: Translate, Phrases, History, Me) and HomePage S-04 (pair pill with swap/pick, engine chip + sheet, Conversation card, Listen/Meeting cards (coming soon until T-1.6/T-1.7), favourite quick phrases row with See all, offline-ready card (cross-feature: language_packs data), Continue card from the latest session)
│   ├── me/             # T-1.11 F-10: MePage S-17 (app language, my languages, offline packs, Translation & voice, Privacy & data, open-source licenses, run setup again, devtools in dev); TranslationVoicePage (engine preference, allow Live in dev, voice speed + sample + install voices, caption size with preview, keep screen on); PrivacyPage (analytics and crash consent, Wi-Fi-only downloads (cross-feature: language_packs notifier), delete all data: option dialog with "also remove packs", second confirm, deleteAllData wipes DB + prefs (+ LanguagePacksNotifier.deleteAll) and onboarding restarts, AC-10.3)
│   ├── phrasebook/     # T-1.9 F-08: PhrasesPage (Quick | Mine; Mine = S-11 with search, pair/tag/★ chips, PhraseRow with play), PhraseDetailPage S-12 (both sides with play, edit translation, note, tags, source session link, show large, favourite, delete with Undo), AddPhrasePage (translation proposed by the current engine, editable); Quick = QuickTab S-13 (Translate into picker, favourites row, situation grid) and SituationPage S-14 (QuickPhraseRow: own language with translation below, slot chips update both, tap speaks or shows, long-press opens show mode, star, save to phrasebook, speaker)
│   ├── conversation/   # T-1.5 S-05 (hero mode, D-27): ConversationNotifier per LanguagePair runs tap-to-talk turns (mic → AudioPipeline with EchoGate → on-device ASR with the side's language → translate on the selected engine, Standard failure falls back to Offline per line → TTS, mic gated while speaking + 150 ms); auto mode (one open mic, detectLanguage limited to [A, B], unclear → the person who did not speak last, AC-02.5); maps Live to Standard until OQ-4; switch toast (AC-02.7), paused banner (AC-02.8); long-press line actions Replay/Save to phrasebook/Copy/Show large (AC-02.6, utteranceIdFor links the phrase to its session); mic and auto taps go through ensureMicAccess first; saves every line (untranslated ones too) to a session started on the first utterance and finished on dispose (AC-02.10); page: partner half RotatedBox 180° with partner-language strings, divider with EngineChip + engine sheet
│   ├── history/        # T-1.8 F-07 (History tab of the shell; transcript route opens on the root navigator): S-09 HistoryPage (sessions grouped by day, FTS search ≥ 2 chars) and S-10 TranscriptPage (engine minutes, per-line fallback badge, rename, share as plain text, delete with confirm, long-press a line to save it to the phrasebook or copy; saved lines show a bookmark); providers in data/notifier/history_providers.dart
│   ├── show_mode/      # S-15 ShowModePage: one line in large text, turnable 180°, optional speak button (`lang`) and hint line (`hint`) (route /show, text passed in `extra`, never in the URL)
│   ├── devtools/       # Dev flavor only (DEVTOOLS_ENABLED): S-23 screen, engine switcher, latency HUD, mic test, benchmark runner + CSV, Remote Config viewer, links to offline packs, Conversation and History
│   ├── language_packs/ # T-1.3 S-16 offline packs: LanguagePacksNotifier (kept alive so downloads go on, AC-06.3; English pivot AC-06.5; Wi-Fi-only + mobile data question AC-06.2; delete keeps shared speech files AC-06.6); repositories over ML Kit model manager, HTTP speech model files (sha256-checked) in AsrModelStore's folder, flutter_tts voice check, connectivity Wi-Fi state
│   └── [FeatureName]/
│       ├── data/
│       │   ├── model/      # Local feature domain models
│       │   ├── notifier/   # Riverpod Notifiers
│       │   ├── repository/ # Data repositories (API calls wrapped in Result)
│       │   └── state/      # Riverpod State classes (using Equatable)
│       └── presentation/
│           ├── view/       # Flutter Pages / Screens
│           └── widget/     # Flutter Widgets used by views
├── gen/                # Auto-generated code (e.g., localization, assets)
├── generated/          # gen-l10n output (AppLocalizations), git-ignored
├── l10n/               # Localization ARB files: intl_en.arb (template) and intl_vi.arb
├── navigation/         # GoRouter configurations and route constants (route_const.dart); onboardingRedirect sends everything to /welcome until onboarding is done and never back after (refreshListenable on onboardingDone); /welcome, /setup, shell tabs / (home), /phrases, /history, /me; /language-packs (S-16); /conversation?a=&b= (S-05); /show (S-15); /history and /history/:id (S-09, S-10); /me/translation and /me/privacy (root navigator); /phrases?tab=quick opens the Quick tab; /phrases/new, /phrases/:id and /phrases/quick/:key (add phrase, S-12, S-14, on the root navigator); /devtools exists only when DEVTOOLS_ENABLED
├── firebase_options_dev.dart  # FlutterFire config for the dev flavor (generated by flutterfire-config.sh)
└── main*.dart          # Entry points: main_dev.dart (dev, initialises Firebase), main_staging.dart, main.dart (production)
```

Product documentation lives outside `lib/` in `project-docs/`; start from
`project-docs/INDEX.md` to find the spec, features (`F-xx`), acceptance criteria, screen
designs (`S-xx`), decisions (`D-xx`) and icons.

## Typography
- Font: Be Vietnam Pro (400/500/600/700, `assets/fonts`, OFL licence registered by `AppConfiguration.registerFontLicenses`) for Material and Cupertino; `AppTheme.textTheme` is the Material 3 scale (`Typography.englishLike2021`) in that font.
- Doc 08 §2.2 styles rounded to the M3 scale (CLAUDE.md): display 40/48 → `displaySmall` 36/44 · captionXL 28/38 → `headlineMedium` 28/36 · captionL 22/30 and title 22/28 → `titleLarge` 22/28 · headline 18/24 → `titleMedium` 16/24 · body 16/24 → `bodyLarge` · original 15/22 → `bodyLarge` 16/24 (legibility on ties) · label 14/20 → `labelLarge` · small 12/16 → `bodySmall` / `labelMedium`. Add `PlatFormThemeDataExtension` getters for these as screens need them.

## Key Patterns
- **Riverpod State Management**: Each feature has `Notifier` classes extending `Notifier<T>` to manage `State` classes which extend `Equatable`.
- **Result Wrapper**: Repositories catch exceptions and return `Result<T>` with either `Result.success(data)` or `Result.failed(error)`.
- **Dependency Injection**: Repositories and Services use `@Singleton` or `@Injectable` from the `injectable` package.
- **Audio**: audio stays in memory (`AudioRingBuffer`), never on disk; ASR engines take segments as in-memory floats. `VoiceActivityDetector` is an interface: `SileroVoiceActivityDetector` (sherpa-onnx) when `silero_vad.onnx` is in `models/`, `EnergyVoiceActivityDetector` otherwise (`vadFactoryProvider`). Segment rules (600 ms silence, 400 ms min speech, 15 s max cut at a ≥ 250 ms pause) live in `SegmenterConfig`. Call `echoGate.setSpeaking` around TTS/Live playback. `AudioPipeline.addPcm` feeds files for the benchmark runner.
- **Local database**: Drift `AppDatabase` (`lib/core/database/`, `wipe()` empties every table), registered as a singleton in `DatabaseModule`. Bump `schemaVersion` and add a migration step for every schema change. Tests open it with `NativeDatabase.memory()`.

## App icons
- Launcher icons per flavor are generated from `assets/brand/png` with `flutter_launcher_icons-<flavor>.yaml` (`fvm dart run flutter_launcher_icons`) into `android/app/src/<flavor>/res`: production uses Lagoon, dev and staging the Graphite variant. Backgrounds are PNG layers, so no colour value lives outside `colors.xml`; foreground inset is 0 because the art already sits in the 66 dp safe zone.
- Notification small icon: `@drawable/ic_stat_lingomate` (`res/drawable-<density>`); never the colour launcher icon.

## Firebase & Environments
- Flavors: dev (`com.lingomate.app.dev`), staging (`com.lingomate.app.staging`), production (`com.lingomate.app`).
- Env files are `KEY=VALUE` files in the root (`.env.dev`, `.env.staging`, `.env`; template `.env.sample`), passed with `--dart-define-from-file` and read in `lib/env.dart`.
- Only dev is connected to Firebase (project `lingo-mate-4f38d`): `lib/firebase_options_dev.dart` and `android/app/src/dev/google-services.json`. Regenerate with `flutterfire-config.sh`.
- `main_dev.dart` startup: `bootstrapFirebase` → `AppConfiguration.ensureAppConfiguration` (DI) → `CrashReporter.installErrorHandlers` → `RemoteConfigService.initialize` (activate last fetch, fetch in background). `RemoteConfigService` and `CrashReporter` work without Firebase (in-app defaults, no reports), so staging and production run before their projects exist.
- Crashlytics mapping upload is turned off for flavors without a `google-services.json` (`android/app/build.gradle`).
- Every push to `main` runs `.github/workflows/distribute-dev.yml`: analyze, test, signed dev release APK, upload to Firebase App Distribution. Secrets, variables and keystore setup: `docs/ci-cd.md`.

## Devtools
- `DEVTOOLS_ENABLED=true` in `.env.dev` turns on the `/devtools` route (opened from Me → Devtools) and the `LatencyHud` overlay in `my_app.dart`. It is a compile-time constant, so production builds contain no devtools code (AC-12.1).
- Pipelines push stage timings with `latencyLogProvider`; engines read the forced engine from `devtoolsProvider`.
- The Live test (`liveTestProvider`) streams the mic's 100 ms chunks to one Live session (target en) or two (vi and en, OQ-4) with the dev `GEMINI_API_KEY`, plays the 24 kHz answer through `PcmPlayer` (native AudioTrack, `android/app/src/main/kotlin/com/lingomate/app/PcmPlayer.kt`, channel `lingomate/pcm_player`), closes the echo gate while it plays and reports the median lag from the first input transcript to the first translated audio.
- The background soak (`soakProvider`) runs Meeting capture (raw mic) inside the foreground service with the caption overlay, and reports elapsed time, segments and the longest gap between audio frames, which shows whether capture paused with the screen off or the app in the background (AC-04.6). Native code: `android/app/src/main/kotlin/com/lingomate/app/` (`TranslationForegroundService`, `CaptionOverlay`, `channels/BackgroundChannel`); notification strings in `res/values(-vi)/strings.xml`.
- The benchmark runs, for each speech model in the app's external `models/` folder, ASR alone, ASR → Gemini (Standard) and ASR → ML Kit (Offline) (`asrModelCatalogProvider` → `benchmarkPipelinesProvider`) over clips in `benchmark/`. English clips translate to Vietnamese, others to English. Setup: `docs/benchmark.md`.

## CI
- `.github/workflows/ci.yml` runs on pull requests and pushes to `main`: code generation, `flutter analyze`, `flutter test`, a production release APK build, a scan that fails on `AIza` keys in the APK, and a check that the APK holds only 64-bit native libraries (`packaging.jniLibs.excludes` in `android/app/build.gradle`).
- Release builds sign with `signing.properties` + `key-release.jks` when present, otherwise with the debug key.

## Scripts & Generation
- Localizations use Flutter's gen-l10n (`l10n.yaml`): edit `lib/l10n/*.arb`, then run `flutter gen-l10n` (`flutter pub get` also runs it). Read strings with `context.localization.<key>`.
- Use `build_runner` for generating Retrofit clients, Injectable DI files, Drift databases and Riverpod lints.
- Example: `dart run build_runner build --delete-conflicting-outputs`
- `scripts/cloud-setup.sh` installs Flutter (via fvm) and the Android SDK in cloud sessions.