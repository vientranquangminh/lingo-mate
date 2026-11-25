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

The owner asked to start Phase 2 with T-2.7, T-2.8 and T-2.9, in that order (2026-11-25). The
other T-2.x tasks and Phase 3 wait until the owner asks.

| Task | Feature | Status | PR / notes |
|------|---------|--------|------------|
| T-2.7 | SRS review and reminders (F-16) | ✅ · 📱 | #33. AC-16.3 timing needs a check on a phone (inexact alarm, doze) |
| T-2.8 | Post-session review, glossary, suggested replies, summaries (F-17–F-20) | ✅ · 📱 | #34. AC-18.2 (glossary benchmark) and AC-19.1 (3 s p50) need measuring; the post-session review waits on `ff_post_session_review` in Remote Config |
| T-2.9 | Privacy policy, Data safety, store listing (en, vi), screenshots | ✅ | #35. `docs/store/` and `hosting/public/`. The owner deploys hosting and enters the kit in Play Console later |

## P1 acceptance criteria

Status: ✅ covered by automated tests, 📱 needs a device check, ⬜ missing, ➖ not in P1.

| Feature | ACs | Status | Gaps / notes |
|---------|-----|--------|--------------|
| F-01 Onboarding | 01.1–01.7 | ✅ | |
| F-02 Conversation | 02.1, 02.2, 02.4–02.8, 02.10 | ✅ | |
| | 02.3 (latency), 02.4 and 02.5 (on device) | 📱 | Measure on the reference phone |
| | 02.9 (Live two-way) | ⬜ | Waits on OQ-4. Live currently maps to Standard |
| F-03 Listen | 03.1–03.6 | ✅ | `test/features/listen/`. 03.4 uses the segmenter's 15 s cut; 03.3 keeps the screen on through `KeepScreenOn` (check on a device) |
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

## Next up (in order)

1. **T-1.13** Internal testing release and bug bash. This needs the owner's devices and testers.

## Waiting on the owner (device and account work)

- Test the voice modes on a phone: the speech model is hosted (GitHub release `models-v1` of the public repo `vientranquangminh/lingomate-models`: `ggml-base.bin`, `ggml-small-q5_1.bin`, `silero_vad.onnx`) and Remote Config `asr_models` points every language at `ggml-base.bin` (2026-11-25). Download a pack in Offline packs, then try Conversation, Listen and Meeting. Switch to `ggml-small-q5_1.bin` if Vietnamese recognition is weak (OQ-3).
- Run the T-0.4 to T-0.8 measurements on the reference phone and a low-end phone, then write the T-0.10 spike report (answers OQ-3, OQ-4, OQ-5).
- Add the App Distribution secrets so CI can ship dev builds.
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
- Learning helpers (T-2.8) run on `model_text_review` and ask for JSON. "User lines" for the post-session review are speaker `a` lines of a Conversation, the user's own half; tips are saved with the user's sentence as source, the native version as translation and the reason as note. Summaries are written in the user's language (`my_language`). Quota counting for these calls waits on T-2.5. Suggest reply sits on the user's half in Conversation (the divider had no room at 200% text) and in the Meeting header once there is a translated line.
- The glossary has one active set at a time ("Use in sessions" on S-22); its terms that appear in an utterance, on either side, go into the Standard prompt. Offline (ML Kit) cannot take a glossary.
- `RatedSpeechSynthesizer` applies the voice speed. Tests that override `speechSynthesizerProvider` bypass it.

## Log

| Date | Change |
|------|--------|
| 2026-11-24 | Phase 0 foundations and spikes (#2–#11); design system T-1.1 (#12–#15) |
| 2026-11-25 | D-26 docs (#16); engines T-1.2 (#17, #18); packs T-1.3 (#19); conversation T-1.5 (#20, #21); history T-1.8 (#22); onboarding T-1.4 (#23); phrasebook T-1.9 (#24); quick phrases T-1.10 (#25); settings T-1.11 (#26); this progress file added (#27); localization T-1.12 (#28); listen mode T-1.6 (#29); meeting mode T-1.7 (#30); speech model hosting guide (#31) and GitHub Releases setup (#32); Phase 2 starts: SRS review T-2.7 (#33); learning helpers and glossary T-2.8 (#34); store kit and privacy policy T-2.9 (#35) |
