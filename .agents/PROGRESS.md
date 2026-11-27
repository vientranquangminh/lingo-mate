# Implementation progress

This is the single source of truth for where the build stands. Read it at the start of every
session, then update it in the same pull request as each feature or fix.

- Plan and task IDs: `project-docs/02-project-plan.md`
- Acceptance criteria: `project-docs/06-feature-details-acs.md`
- Code map: `.agents/CONTEXT.md`

Last updated: 2026-11-25. Phase 2 started at the owner's request: T-2.7 SRS review (#33), T-2.8 learning helpers and glossary (#34), T-2.9 store kit and privacy policy (#35).

## How to resume in a new session

1. Read `CLAUDE.md`, this file and `.agents/CONTEXT.md`.
2. Run `git fetch origin main` and check that **Open pull requests** below still matches GitHub.
3. Take the first task under **Next up**, unless the owner asks for something else.
4. Branch from the latest `main` as `<type>/<topic>`, for example `feat/t-1.12-localization`.
5. Before you push:
   - run `fvm flutter analyze` and `fvm flutter test`
   - build a dev debug APK with `.env.dev`, created from `.env.sample` and deleted afterwards
6. Open a PR into `main`. The owner has said that a PR whose CI is green may be squash-merged.
7. In the same PR, update this file: the task row, the AC table, **Next up** and the log at the bottom.

Status legend:

- ✅ done (merged)
- 🔄 in review (PR open)
- 🚧 in progress
- ⬜ not started
- 📱 code done, needs measuring on a physical device

## Phase 0: Spike & foundations

| Task | What | Status | PR / notes |
|------|------|--------|------------|
| T-0.1 | Repo bootstrap, flavors, Drift, CI | ✅ | #2, #3, #5 |
| T-0.2 | Firebase dev: App Check, Remote Config, AI Logic, Crashlytics | ✅ | #4 |
| T-0.3 | Audio core: capture, VAD, segmenter, ring buffer, echo gate | ✅ | #6 |
| T-0.4 | ASR spike: sherpa-onnx and whisper.cpp behind `SpeechRecognizerEngine` | ✅ code · 📱 | #8. OQ-3 needs benchmark numbers from a device |
| T-0.5 | Live spike: Live Translate client, devtools Live test | ✅ code · 📱 | #10. OQ-4 and OQ-5 need device measurements |
| T-0.6 | Standard pipeline (Gemini Flash-Lite) | ✅ code · 📱 | #9 |
| T-0.7 | Offline pipeline (ML Kit) | ✅ code · 📱 | #9 |
| T-0.8 | Foreground service, caption overlay, 30-min soak | ✅ code · 📱 | #11. The soak must run on the reference phone and a low-end phone |
| T-0.9 | Benchmark harness and devtools | ✅ | #7 |
| T-0.10 | Spike report `docs/spike-report.md` | ⬜ | Blocked on the device runs above (owner) |

## Phase 1: Core alpha

| Task | Feature | Status | PR / notes |
|------|---------|--------|------------|
| T-1.1 | Design system: theme, tokens, icons, launcher icons, fonts | ✅ | #12, #13, #14, #15 |
| T-1.2 | Engine layer, selector, capability matrix, engine chip | ✅ | #17, #18 |
| T-1.3 | Language packs (F-06) | ✅ | #19 |
| T-1.4 | Onboarding and permission explainers (F-01), Home shell, Me | ✅ | #23 |
| T-1.5 | Conversation (F-02) | ✅ · 📱 | #20, #21, #23 (bug fix). Two-way Live waits on OQ-4 |
| T-1.6 | Listen mode (F-03) | ✅ | #29. Live maps to Standard, as in Conversation; Live captions and earphone audio come later |
| T-1.7 | Meeting mode (F-04): service, overlay, in-app transcript | ✅ · 📱 | #30. AC-04.6, 04.7 and 04.9 need the reference phone; Live maps to Standard |
| T-1.8 | Sessions and transcripts (F-07) | ✅ | #22 |
| T-1.9 | Phrasebook (F-08) | ✅ | #24 |
| T-1.10 | Quick phrases (F-09) | ✅ | #25 |
| T-1.11 | Settings and privacy (F-10) | ✅ | #26 |
| T-1.12 | Localization (F-11) | ✅ · 📱 | #28. AC-11.6 needs a check in system Settings on an Android 13+ phone |
| T-1.13 | Internal testing release, bug bash | ⬜ | Needs the owner's devices and testers |

## Phase 2: Learning, accounts and store

The owner asked to start Phase 2 with T-2.7, T-2.8 and T-2.9 (2026-11-25), then asked for every
remaining mobile-side task (Flutter code and its config): accounts, account deletion, usage
limits, Live on the client, and Phase 3. Pricing/RevenueCat (T-2.6), production config (T-2.1)
and Firebase production setup come last, when the owner has time. Cloud Functions are server
side: the app calls them as doc 03 describes and copes while they are missing.

| Task | Feature | Status | PR / notes |
|------|---------|--------|------------|
| T-2.7 | SRS review and reminders (F-16) | ✅ · 📱 | #33. AC-16.3 timing needs a check on a phone (inexact alarm, doze) |
| T-2.8 | Post-session review, glossary, suggested replies, summaries (F-17–F-20) | ✅ · 📱 | #34. AC-18.2 (glossary benchmark) and AC-19.1 (3 s p50) need measuring; the post-session review waits on `ff_post_session_review` in Remote Config |
| T-2.9 | Privacy policy, Data safety, store listing (en, vi), screenshots | ✅ | #35. `docs/store/` and `hosting/public/`. The owner deploys hosting and enters the kit in Play Console later |
| — | Kill switches for paid features (owner's idea) | ✅ | #36. Remote Config `ff_standard_enabled`, `ff_summary`, `ff_suggest_reply`, `ff_glossary`, `ff_cloud_speech` (default on), applied live through `onConfigUpdated` |
| T-2.2 | Accounts (F-13), part 1: anonymous start, S-24 sign-in (Google, email link), account details, sign out, Me account card and stats | ✅ · 📱 | #37. Needs the providers turned on in the dev Firebase console (see Waiting on the owner). Sync, merge and Firestore rules come in part 2 |
| T-2.2 | Accounts (F-13), part 2: sync, merge prompt, Firestore rules | ✅ · 📱 | #38. Sync runs against a fake store in tests; real Firestore needs the rules deployed and Firestore created on the dev project |
| T-2.12 | Account deletion (F-13), app side and web page | ✅ · 📱 | #39. Calls the `deleteAccount` function, which is server work not written yet; until it exists the app says deletion failed. `/delete-account` sends an email request |
| T-2.5 | Usage limits (F-14), app side: Standard metering, windows, usage sheet, warnings, Free plan card | ✅ | #40. Live limits are enforced by `issueLiveToken` (server, T-2.3); syncing `usage/standard` to Firestore waits on the server work too |
| T-2.4 | Live on the client (F-05): token requests, captions in Listen and Meeting, block renewal, fallback | ✅ · 📱 | #41. Production tokens need `issueLiveToken`/`reportLiveUsage` (server, T-2.3) and `ff_live_enabled`; dev keeps using the API key. Two-way Conversation on Live still waits on OQ-4; captions only, no translated audio yet |

## Phase 3: Global and growth (mobile side)

| Task | Feature | Status | PR / notes |
|------|---------|--------|------------|
| T-3.5 | Home widget and Quick Settings tile (F-23) | ✅ · 📱 | #42. Widget: Start conversation and four starred quick phrases; tile starts Meeting in the app or stops it while running |
| T-3.4 | Roleplay practice (F-22) | ✅ · 📱 | #50. Text and voice answers, partner lines with translation and speaker, feedback with Save; behind `ff_roleplay` |
| T-3.3 | Media capture mode (F-21) | ✅ · 📱 | #51. Home → Media opens Listen on the phone's playback (MediaProjection + AudioPlaybackCapture in `MediaCaptureService`); needs checking with a browser video on a phone |
| T-3.1 | Wave-1 UI languages and store listings (F-24) | ✅ · 📱 | #52. ja, ko, zh, th, id, es, fr, de ARBs (machine-drafted, need a native review before release), endonyms and `locales_config.xml`; listings in `docs/store/listing.<lang>.md`; screens checked for overflow at 2.0× in every language. AC-24.2 (region-block messaging) still needs a check per market |

## P1 acceptance criteria

Status: ✅ covered by automated tests, 📱 needs a device check, ⬜ missing, ➖ not in P1.

| Feature | ACs | Status | Gaps / notes |
|---------|-----|--------|--------------|
| F-01 Onboarding | 01.1–01.7 | ✅ | |
| F-02 Conversation | 02.1, 02.2, 02.4–02.8, 02.10 | ✅ | |
| | 02.3 (latency), 02.4 and 02.5 (on device) | 📱 | Measure on the reference phone |
| | 02.9 (Live two-way) | ✅ · 📱 | Two Live sessions on one open mic, translated speech played with the mic gated (`conversation_live_test.dart`); lag and echo need measuring on a phone (OQ-4) |
| F-03 Listen | 03.1–03.6 | ✅ | `test/features/listen/`. 03.4 uses the segmenter's 8 s cut (was 15 s, owner latency feedback); 03.3 keeps the screen on through `KeepScreenOn` (check on a device) |
| F-04 Meeting | 04.1–04.5, 04.8 | ✅ | `test/features/meeting/`; overlay drawing, dragging and per-line long-press are native (`CaptionOverlay.kt`), check them on a device |
| | 04.6, 04.7, 04.9 | 📱 | 30-minute soak, latency and battery on the reference phone |
| F-05 Engines | 05.1–05.8 | ✅ | |
| F-06 Packs | 06.1–06.7 | ✅ | 06.3 (progress while away) 📱 |
| F-07 History | 07.1–07.6 | ✅ | |
| F-08 Phrasebook | 08.1–08.6 | ✅ | |
| F-09 Quick phrases | 09.1–09.6 | ✅ | 09.2 "within 500 ms" 📱 |
| F-10 Settings | 10.2, 10.3, 10.5 | ✅ | 10.1 is covered by F-11 |
| | 10.4 | ✅ · 📱 | Gating is tested. Check DebugView on a device |
| F-11 Localization | 11.1–11.5, 11.8, 11.9 | ✅ | 11.1 `test/l10n/hard_coded_strings_test.dart`; 11.2 `test/l10n/screens_golden_test.dart` (18 screens × en/vi × 1.0/2.0); 11.8 `PartnerStrings`; 11.9 `arb_files_test.dart` and the CI step `scripts/check-untranslated.sh` |
| | 11.6 Android 13 per-app language | ✅ · 📱 | `locales_config.xml`, `AppLocaleChannel` and `AppLocaleSync` are tested; check system Settings → App languages on a device |
| | 11.7 `uiLocale` when signed in | ➖ | P2 |
| F-12 Devtools | 12.1–12.4 | ✅ | |

## P2 acceptance criteria

| Feature | ACs | Status | Gaps / notes |
|---------|-----|--------|--------------|
| F-16 Review | 16.1, 16.2 | ✅ | `test/core/review/sm2_test.dart` (SM-2 reference values), `review_repository_test.dart`, `test/features/review/`; cards live in the local DB, so review needs no network |
| | 16.3 reminder | ✅ · 📱 | Scheduling is tested (`review_reminder_test.dart`); check that the notification shows at the chosen time on a phone |
| F-17 Post-session review | 17.1–17.3 | ✅ | `test/features/learning/learning_pages_test.dart`, `test/core/learning/`. Shown only while Remote Config `ff_post_session_review` is true (default false, doc 03 §11) |
| F-18 Glossary | 18.1 | ✅ | `test/features/glossary/`, `test/core/glossary/glossary_test.dart`. The set switched to "Use in sessions" applies to the sessions that follow |
| | 18.2 benchmark | 📱 | The prompt carries the matching terms (tested); the ≥ 90% rate needs benchmark glossary clips. No ASR hint yet: neither speech engine takes a prompt in our setup |
| F-19 Suggested replies | 19.1, 19.2 | ✅ · 📱 | Conversation speaks, Meeting copies (page tests); 3 s p50 needs measuring on a phone |
| F-20 Summary | 20.1, 20.2 | ✅ | `learning_pages_test.dart`: Meeting/Listen ≥ 3 min, stored in `sessions.summary`, shared as text |
| F-21 Media capture | 21.1, 21.2 | ✅ · 📱 | `test/features/listen/listen_media_test.dart` (captions from the playback capture, a `media` session, the 10 s silence notice); consent and capture are native, check them on a phone |
| F-22 Roleplay | 22.1 | ✅ · 📱 | `test/features/roleplay/roleplay_test.dart` with the fake assistant; the voice answer uses on-device ASR in the target language, check it on a phone |
| F-23 Widget and tile | 23.1, 23.2 | ✅ · 📱 | `test/features/widget/home_widget_test.dart` (favourites sent to the widget, links open Conversation and say a phrase), meeting page auto-start; the widget and tile themselves are native (`HomeWidget.kt`, `MeetingTileService.kt`), check them on a phone |
| F-14 Usage | 14.1, 14.6, 14.7, 14.8 (client) | ✅ | `test/core/quota/quota_engine_test.dart` (windows, reset, limits from Remote Config, metering), `test/features/me/usage_test.dart` (plan card, usage sheet, 80% and 100% notices); exhausted Standard blocks it in the selector, so the next line goes Offline |
| | 14.2–14.5, 14.9 | ⬜ | Server side (`issueLiveToken`, `reportLiveUsage`, rules tests) |
| F-13 Account | 13.1, 13.2, 13.3, 13.5, 13.7, 13.8, 13.11 | ✅ · 📱 | `test/features/account/` with a fake `AuthService`; real Google and email-link sign-in need the console setup and a phone. The plan card on Me waits on T-2.5/T-2.6 |
| | 13.4 merge, 13.9 sync, 13.10 | ✅ · 📱 | `test/core/sync/sync_engine_test.dart` (two phones on one fake store: create, edit, last write wins, tombstones, review cards, glossaries, duplicate merge) and the account page tests; the 10 s timing needs two phones. Transcripts are never uploaded (no transcript sync yet) |
| | 13.6 Live sign-in | ✅ · 📱 | Listen and Meeting ask to sign in before starting on Live; declining runs the session on Standard |
| | 13.12, 13.13 deletion in the app | ✅ · 📱 | Account page tests with a fake `AuthService`: Google sign-in again, confirm, server call, phone wiped, onboarding again; email accounts get a fresh link when the login is old; the Google Play note and link always show (no purchase state yet) |
| | 13.14 web page | ✅ · 📱 | `hosting/public/delete-account.html` opens an email request to the owner; processing it through `deletionRequests` waits on the server |

## Next up (in order)

1. **T-1.13** Internal testing release and bug bash. This needs the owner's devices and testers.

## Waiting on the owner (device and account work)

- Test the voice modes on a phone: the speech model is hosted (GitHub release `models-v1` of the public repo `vientranquangminh/lingomate-models`: `ggml-base.bin`, `ggml-small-q5_1.bin`, `silero_vad.onnx`) and Remote Config `asr_models` points every language at `ggml-base.bin` (2026-11-25). Download a pack in Offline packs, then try Conversation, Listen and Meeting. Switch to `ggml-small-q5_1.bin` if Vietnamese recognition is weak (OQ-3).
- Run the T-0.4 to T-0.8 measurements on the reference phone and a low-end phone, then write the T-0.10 spike report (answers OQ-3, OQ-4, OQ-5).
- Add the App Distribution secrets (docs/ci-cd.md §1–3) so pushes to `staging` ship test builds; until then the workflow skips.
- Accounts (T-2.2) on the dev project: in Firebase console → Authentication → Sign-in method turn on Anonymous, Google and Email/Password with Email link; add the SHA-1 and SHA-256 of the debug and release keys to the dev Android app (Project settings), then download `google-services.json` again into `android/app/src/dev/` so Google sign-in gets its web client id. Staging and production use placeholder link hosts (`lingo-mate-staging/prod.firebaseapp.com` in `android/app/build.gradle`) until T-2.1.
- Sync on the dev project: create the Firestore database (Native mode) and deploy the rules with `firebase deploy --only firestore:rules --project lingo-mate-4f38d`. Rules tests in the emulator are still to write (doc 07).
- Account deletion (T-2.12) needs the `deleteAccount` callable (Cloud Functions, server side): delete `users/{uid}` recursively, live tokens, the RevenueCat customer, then the Auth user, refusing logins older than 5 minutes with `failed-precondition`. Until then, delete requests arrive by email from `/delete-account`.
- Privacy policy (T-2.9): the contact email is filled in; run `firebase login` and `firebase deploy --only hosting --project lingo-mate-4f38d` to publish `/privacy` and `/privacy-vi`. Move hosting and `privacy_policy_url` to the production project with T-2.1.
- Later (owner): paste the listing, Data safety answers, screenshots, icon and feature graphic from `docs/store/` into Play Console, after the store name check (OQ-7).
- Turn on `ff_post_session_review` in Remote Config (dev) to try the post-session review (F-17), and measure Suggest reply latency (AC-19.1, 3 s p50).
- Add glossary clips to `benchmark/` to measure AC-18.2.
- Device check for the review reminder (AC-16.3): turn on Phrases → Review → settings → Daily reminder, pick a time a few minutes ahead with a card due, lock the phone and wait.
- Device checks: the Meeting overlay (drag, tap to expand, Stop, long-press a line, position kept), AC-02.3, AC-02.4, AC-02.5, AC-04.6, AC-04.7, AC-04.9, AC-06.3, AC-09.2 (timing), AC-10.4 (DebugView) and AC-11.6 (system Settings → App languages on Android 13+, both directions).
- Have native speakers review the partner strings for ja, ko, zh, th, id, es, fr and de in `lib/l10n/partner_strings.dart`.
- Decide whether analytics and crash consent should start off (they start on, set in #26).

## Known follow-ups and decisions taken

- Auto and Prefer Standard pick engines in the same order (Standard, then Offline). Only Prefer Offline changes the order.
- Quick phrase rows show the user's language first and the translation below, as F-09 says. The S-14 mockup shows the reverse.
- Screen goldens (`test/l10n/goldens`) are compared only on Linux, as in CI. After a UI change, regenerate them with `fvm flutter test test/l10n/screens_golden_test.dart --update-goldens` and look at the changed images. The test font has no CJK or arrow glyphs, so those show as blanks; a phone falls back to system fonts.
- Listen (F-03) uses the Conversation engine mapping: Live falls back to Standard. Auto source picks among the user's partner languages (English when there are none). Captions are saved as a `listen` session with no speaker.
- `showCaptionSettingsSheet` (caption size slider and keep screen on) and `SourceLanguagePill` are shared by Listen and Meeting.
- Meeting (F-04) keeps one session in `meetingProvider` (not auto-disposed), so captions go on while the user moves around the app; the Home card says when it is running. A new speaker turn is a pause of 3 s or more (no diarization). The overlay shows a Toast when a line is saved. The Live toggle of S-07 waits on Live captions.
- Partner strings for wave-1 languages that are not UI languages live in `PartnerStrings.bundled`; en and vi come from the ARB files.
- Review (F-16) follows SM-2: the first answer of a session schedules the card; Again and Hard bring it back at the end of the session until it is graded Good or Easy, and those repeats don't change the schedule. Each phrase has a forward and a reverse card. The reminder is a daily inexact alarm set for the first reminder time on or after the earliest due card, re-synced when the app starts, goes to the background and after a session, so it only fires on days with cards due.
- The privacy policy lives in `hosting/public/` (Firebase Hosting, `/privacy` and `/privacy-vi`); Me → Privacy & data → Privacy policy opens Remote Config `privacy_policy_url` (default: the dev project's hosting URL). Data safety answers in `docs/store/data-safety.md` cover the build without accounts, purchases or production Live; update both when those ship. Store screenshots come from `test/store/store_screenshots_test.dart` (skipped unless `--dart-define=STORE_SCREENSHOTS=true`); the test font has no `⇄` glyph, so language pairs show without the arrow there.
- Accounts: `AuthService` (`core/auth`) hides Firebase Auth; builds without Firebase get `LocalOnlyAuthService` and no account card. Every install signs in anonymously at start; Google (google_sign_in 7, Credential Manager) and email links link to that uid, and an identity that already has an account signs in to it (merge prompt comes with sync). Email links open the app through an App Links intent filter on `${authLinkHost}/__/auth/links`; `MyApp` completes them and opens `/email-link` when the address must be confirmed or the link failed. `requireSignIn(context, ref, reason)` opens S-24 and returns whether it worked. Sign out offers Keep / Remove this phone's data (`AppDatabase.wipeUserData` keeps language packs) and continues anonymously.
- Sync (F-13): opt-in switch in Privacy & data (asks to sign in first). `SyncController` runs `SyncEngine` while sync is on and a real account is signed in: it pushes rows changed since the last push (per uid, in prefs) and applies Firestore snapshots where the cloud `updatedAt` is newer. Phrases carry tag names; review cards and glossary terms wait for their phrase or set; a synced phrase soft-deletes a local duplicate (same source text and pair). Glossary deletes are now soft (schema 6 adds `updated_at`/`deleted_at` to glossary tables and `updated_at` to review cards). Which glossary set is in use stays per phone. Cloud layout: `users/{uid}/phrases`, `srs`, `glossary` and `glossaryTerms` (flat, not under `glossary/{setId}/terms` as doc 03 §9.2 shows, so one listener covers all terms). Signing in to an account that already existed asks Merge / Don't merge when the phone has phrases; Don't merge clears the phrasebook, review cards and glossaries on the phone.
- Media capture (F-21): the Media card on Home opens Listen with `media=1`. `mediaListenProvider` runs the same `ListenNotifier` on `PlaybackAudioCapture` (channel `lingomate/media_capture`: consent through `createScreenCaptureIntent`, then `MediaCaptureService`, a mediaProjection foreground service reading `AudioPlaybackCapture` for media, game and unknown usages at 16 kHz, streamed over `lingomate/media_capture/audio`). Sessions are saved as `media`. When the captured level stays under -60 dBFS for 10 s the screen explains that the playing app may block capture. Calls cannot be captured, which the intro says.
- Roleplay (F-22): Situation S-14 has a Practise action (hidden when `ff_roleplay` is off). `RoleplayNotifier` asks `LearningAssistant.roleplay` for the partner's next line in the partner language (with a translation) and feedback on the learner's last line (`PhrasingTip` with `meaning`, so it saves as own language → partner language). Answers are typed, or spoken once through on-device ASR in the partner language and put in the text box to edit before sending. Needs internet.
- Widget and tile (F-23): `HomeWidgetProvider` draws Start conversation and up to four favourites sent from Dart (`homeWidgetSyncProvider` → channel `lingomate/home_widget`, labels in the user's language for the current pair). Taps open `lingomate://open/conversation` or `/quick?key=` (said in the partner language, or shown when no voice). `MeetingTileService` reads `TranslationForegroundService.running`: tapping it stops captions while running, otherwise opens `lingomate://open/meeting?start=1`, which starts Meeting (Android does not allow starting the microphone service from the tile itself).
- Realtime (owner feedback 2026-11-25: too slow, online state confusing): Conversation now runs two-way Live when the selector picks it — one session into each language on the same open mic (`echoTargetLanguage` false keeps each silent for its own language), turns appear as the transcripts arrive, translated speech plays through `livePlayerProvider` with the echo gate held until it ends, the speaker button mutes it. Tapping either mic or Auto starts and stops Live; sign-in is asked first; any refusal or drop falls back to text auto mode with a toast. The engine sheet now says what each engine does (Live realtime, Standard after each sentence, Offline on the phone). Test builds need `GEMINI_API_KEY` in the staging secrets for Live.
- Faster offline speech (owner feedback 2026-11-25): Whisper now sizes its encoder context to the segment (`WhisperCppEngine.audioContextFor`) instead of padding every line to 30 s, with token timestamps off and a single greedy pass; a sentence ends after 500 ms of silence (was 600). While someone speaks, `AudioPipeline.partials` sends the speech so far about once a second and `PartialTranscriber` shows the words heard so far (`draft`, `DraftLine`) in Listen, Meeting and tap-to-talk Conversation, replaced by the caption when the sentence ends; partials never run while a finished sentence is being processed. Translation still happens once per sentence.
- Meeting speakers (owner feedback 2026-11-27: Meeting could not tell who was speaking): each segment gets a voice embedding (3D-Speaker CAM++, 28 MB, downloaded with the first speech pack) and `SpeakerTracker` numbers voices in the order they first speak. Lines show a coloured bar and "Speaker N" when the speaker changes, in the app and the floating bubble. Tested on clips: same speaker ≥ 0.53 cosine for 1 s+ halves, different speakers ≤ 0.23; threshold 0.4. Not on Live (no segments). Also fixed: the model catalog now refreshes after a pack download or delete, so new speech models apply without restarting.
- Vietnamese accents (owner feedback 2026-11-27: a Đà Nẵng accent was mostly misrecognised, only the Hà Nội accent worked): on the phone, Vietnamese now uses the k2-fsa zipformer transducer trained on ~70k hours (`SherpaTransducerEngine` behind `LanguageRoutedRecognizer`; other languages keep Whisper). Packs can be `.tar.bz2` model folders, checked and unpacked after download. The owner points the `vi` entry of `asr_models` at it (JSON in `docs/speech-models.md`). Gemini's prompt for Standard now says the speaker may have a Northern, Central or Southern accent.
- Visual polish (owner request 2026-11-26): Me settings sit in two rounded grouped cards with single-line values; Listen, Meeting, History and Phrases empty states show an icon in a tinted circle; the Phrases add button is a primary pill with a label; Media on Home is a compact horizontal card; quick-phrase tiles share a minimum height; switching tabs fades and lifts the tab in; the mic and the tab bar give light haptics. Screen goldens regenerated.
- Motion and the meeting bubble (owner feedback 2026-11-26): loading lists show shimmering skeletons instead of spinners; new captions, meeting lines and roleplay bubbles fade and slide in; a line's translation cross-fades in over "Translating…"; usage bars, pack downloads and the engine chip label animate; the roleplay partner shows typing dots. Everything honours the system "remove animations" setting. The floating caption bubble was hard to use (any tap toggled expand, it jittered on tap, a single tap on a tiny square stopped the meeting, it could be dragged off screen and could not get out of the way): it now drags by its header past the touch slop and snaps to a side, has Minimise (to a pill), Expand (scrolling, capped height) and a two-tap Stop, and shows … for pending lines. Needs a check on a phone.
- Lower latency (owner feedback 2026-11-25: 4–10 s delays on a test build): phones had no Silero VAD (the packs only download Whisper), so the fixed −45 dBFS energy detector heard any room noise as speech and sentences only ended at the 15 s cut. Silero VAD now ships in the app (`assets/models/silero_vad.onnx`, 644 KB) and is copied into `models/` on first use; the energy fallback follows the room's noise floor (capped at −35 dBFS). Sentences are cut at 8 s (at the latest pause), the next sentence is recognised while the previous one is still being translated (Listen, Meeting), and partial transcription rests as long as its last run took so it never takes more than half the CPU. Next lever, owner side: a quantized Whisper (`ggml-base-q5_1.bin`, ~57 MB) runs faster and downloads faster.
- More accurate Standard (owner feedback 2026-11-25: fast but not accurate enough, compared with Teams): on Standard, Gemini now hears each sentence and translates it in one call (`SpeechTranslatorEngine` → `GeminiSpeechTranslator`, `hearOnCloud`), in Listen, Meeting and Conversation; on-device Whisper only shows the words while speaking and takes over when the call fails. Remote Config `model_speech_translate` (default `gemini-2.5-flash`) and `ff_cloud_speech` (default on). The privacy policy and the Data safety notes now say Standard and Live send audio to Google. Without a downloaded speech model, Standard still starts and runs on Gemini alone (`recognizerFor` → `CloudOnlyRecognizer`, no live partials); Offline and Live need what they needed before.
- Live on the client (T-2.4): `LiveAccess` asks for a block (`DevLiveAccess` with the dev API key; `CallableLiveAccess` calls `issueLiveToken` and `reportLiveUsage`). `LiveCaptioner` opens one Live Translate session into the user's language, turns transcripts into one caption per turn, renews the block 5 s before it ends (reporting the seconds used) and reports a stop on refusal, error or close. Listen and Meeting use it when the selector picks Live: lines carry engine `live` and are metered; any refusal or drop switches the screen to the text engines with a toast (and the usage sheet when out of Live time). `liveAvailableProvider` now allows Live wherever `ff_live_enabled` is on and Firebase is set up (or the dev flavor). Conversation still maps Live to Standard (OQ-4), and Live audio is not played in Listen or Meeting.
- Usage (F-14): every Standard or Live line saved to a session writes its seconds (rounded up) to `usage_ledger`; Offline is never metered. `standardQuotaProvider` turns the last two weeks of Standard rows into the 5-hour and weekly windows (`QuotaEngine`, limits from `quota_limits` for the Free plan until purchases exist) and refreshes every 30 s. When either window runs out the selector blocks Standard with `standardQuota`. `MyApp` shows a toast at 80% and at 100% with See usage. Me shows a Free plan card with the Standard week bar that opens the usage sheet (S-18, Standard only; Live rows come with T-2.4). The learning helpers are not metered yet.
- Kill switches: every Gemini feature has its own Remote Config flag (`FeatureSwitches`, `featureSwitchesProvider`). They default on (the post-session review defaults off, doc 03 §11) and apply without a restart: `RemoteConfigService.updates` activates values from `onConfigUpdated`. Standard off blocks it with `EngineBlock.standardDisabled`, so sessions fall back to Offline; Summarize and Suggest reply buttons hide; glossary terms stop going into prompts. These keys are not in doc 03 §11 yet.
- Learning helpers (T-2.8) run on `model_text_review` and ask for JSON. "User lines" for the post-session review are speaker `a` lines of a Conversation, the user's own half; tips are saved with the user's sentence as source, the native version as translation and the reason as note. Summaries are written in the user's language (`my_language`). Quota counting for these calls waits on T-2.5. Suggest reply sits on the user's half in Conversation (the divider had no room at 200% text) and in the Meeting header once there is a translated line.
- The glossary has one active set at a time ("Use in sessions" on S-22); its terms that appear in an utterance, on either side, go into the Standard prompt. Offline (ML Kit) cannot take a glossary.
- `RatedSpeechSynthesizer` applies the voice speed. Tests that override `speechSynthesizerProvider` bypass it.

## Log

| Date | Change |
|------|--------|
| 2026-11-24 | Phase 0 foundations and spikes (#2–#11); design system T-1.1 (#12–#15) |
| 2026-11-25 | D-26 docs (#16); engines T-1.2 (#17, #18); packs T-1.3 (#19); conversation T-1.5 (#20, #21); history T-1.8 (#22); onboarding T-1.4 (#23); phrasebook T-1.9 (#24); quick phrases T-1.10 (#25); settings T-1.11 (#26); this progress file added (#27); localization T-1.12 (#28); listen mode T-1.6 (#29); meeting mode T-1.7 (#30); speech model hosting guide (#31) and GitHub Releases setup (#32); Phase 2 starts: SRS review T-2.7 (#33); learning helpers and glossary T-2.8 (#34); store kit and privacy policy T-2.9 (#35); kill switches for paid features (#36); accounts part 1 (#37); sync and merge (#38); account deletion (#39); usage limits (#40); Live on the client (#41); widget and tile (#42); test builds from the `staging` branch (#43); two-way Live Conversation (#44); faster offline speech with words shown while speaking (#45); lower latency: bundled Silero VAD, 8 s cut, translation off the recognition queue (#46); Standard hears speech with Gemini (#47); staging builds without a release keystore (#48); Standard without a speech model (#49); Phase 3: roleplay T-3.4 (#50); media capture T-3.3 (#51); wave-1 UI languages T-3.1 (#52); motion and an easier meeting bubble (#53); visual polish (#54); Vietnamese transducer for regional accents (#55); Meeting speaker labels (#56) |
