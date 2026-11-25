# Implementation progress

This is the single source of truth for where the build stands. Read it at the start of every
session, then update it in the same pull request as each feature or fix.

- Plan and task IDs: `project-docs/02-project-plan.md`
- Acceptance criteria: `project-docs/06-feature-details-acs.md`
- Code map: `.agents/CONTEXT.md`

Last updated: 2026-11-25. T-1.10 is merged and T-1.11 is in review as #26.

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
| T-1.6 | Listen mode (F-03) | ⬜ | Home card shows "coming soon" |
| T-1.7 | Meeting mode (F-04): service, overlay, in-app transcript | ⬜ | The service and overlay from T-0.8 can be reused |
| T-1.8 | Sessions and transcripts (F-07) | ✅ | #22 |
| T-1.9 | Phrasebook (F-08) | ✅ | #24 |
| T-1.10 | Quick phrases (F-09) | ✅ | #25 |
| T-1.11 | Settings and privacy (F-10) | 🔄 | #26 |
| T-1.12 | Localization (F-11) | 🚧 partly | en and vi ARBs and the App language setting exist. See the F-11 ACs for what is missing |
| T-1.13 | Internal testing release, bug bash | ⬜ | After T-1.6, T-1.7 and T-1.12 |

Phase 2 (T-2.x) and Phase 3 (T-3.x) have not started. Do not begin them unless the owner asks.

## P1 acceptance criteria

Status: ✅ covered by automated tests, 📱 needs a device check, ⬜ missing, ➖ not in P1.

| Feature | ACs | Status | Gaps / notes |
|---------|-----|--------|--------------|
| F-01 Onboarding | 01.1–01.7 | ✅ | |
| F-02 Conversation | 02.1, 02.2, 02.4–02.8, 02.10 | ✅ | |
| | 02.3 (latency), 02.4 and 02.5 (on device) | 📱 | Measure on the reference phone |
| | 02.9 (Live two-way) | ⬜ | Waits on OQ-4. Live currently maps to Standard |
| F-03 Listen | 03.1–03.6 | ⬜ | T-1.6. 03.3 and 03.5 can reuse `KeepScreenOn` and `CaptionScale` |
| F-04 Meeting | 04.1–04.9 | ⬜ | T-1.7. 04.6, 04.7 and 04.9 are device soak checks |
| F-05 Engines | 05.1–05.8 | ✅ | |
| F-06 Packs | 06.1–06.7 | ✅ | 06.3 (progress while away) 📱 |
| F-07 History | 07.1–07.6 | ✅ | |
| F-08 Phrasebook | 08.1–08.6 | ✅ | |
| F-09 Quick phrases | 09.1–09.6 | ✅ | 09.2 "within 500 ms" 📱 |
| F-10 Settings | 10.2, 10.3, 10.5 | 🔄 | In #26. 10.1 is covered by F-11 |
| | 10.4 | 🔄 · 📱 | Gating is tested. Check DebugView on a device |
| F-11 Localization | 11.3, 11.4, 11.5 | ✅ | |
| | 11.1 hard-coded string check | ⬜ | Add a test or lint over `presentation/` |
| | 11.2 en and vi goldens at 1.0 and 2.0 | ⬜ | Several 200% widget tests exist; no golden suite yet |
| | 11.6 Android 13 per-app language | ⬜ | Needs `locales_config.xml`, `android:localeConfig` and a LocaleManager sync channel |
| | 11.7 `uiLocale` when signed in | ➖ | P2 |
| | 11.8 partner strings in every wave-1 language | ⬜ | Partner half falls back to English except vi |
| | 11.9 CI untranslated-key check | ⬜ | `untranslated-messages-file` plus a CI step |
| F-12 Devtools | 12.1–12.4 | ✅ | |

## Next up (in order)

1. **Merge #26 (T-1.11)** once CI is green, then mark T-1.11 ✅ here.
2. **T-1.12 Localization.** Close the F-11 gaps: 11.1, 11.2, 11.6, 11.8 and 11.9.
3. **T-1.6 Listen mode (F-03).** S-06: caption list, jump to live, keep screen on, font size, pause.
4. **T-1.7 Meeting mode (F-04).** Setup card, overlay permission explainer, service notification, overlay bubble with save, stop flow, in-app transcript.
5. **T-1.13** Internal testing release and bug bash. This needs the owner's devices and testers.

## Waiting on the owner (device and account work)

- Push speech models with adb, or fill the Remote Config `asr_models` entry, so Offline works on a phone.
- Run the T-0.4 to T-0.8 measurements on the reference phone and a low-end phone, then write the T-0.10 spike report (answers OQ-3, OQ-4, OQ-5).
- Add the App Distribution secrets so CI can ship dev builds.
- Device checks: AC-02.3, AC-02.4, AC-02.5, AC-04.6, AC-04.7, AC-04.9, AC-06.3, AC-09.2 (timing) and AC-10.4 (DebugView).
- Decide whether analytics and crash consent should start off (they start on in #26).

## Known follow-ups and decisions taken

- Auto and Prefer Standard pick engines in the same order (Standard, then Offline). Only Prefer Offline changes the order.
- Quick phrase rows show the user's language first and the translation below, as F-09 says. The S-14 mockup shows the reverse.
- `RatedSpeechSynthesizer` applies the voice speed. Tests that override `speechSynthesizerProvider` bypass it.

## Log

| Date | Change |
|------|--------|
| 2026-11-24 | Phase 0 foundations and spikes (#2–#11); design system T-1.1 (#12–#15) |
| 2026-11-25 | D-26 docs (#16); engines T-1.2 (#17, #18); packs T-1.3 (#19); conversation T-1.5 (#20, #21); history T-1.8 (#22); onboarding T-1.4 (#23); phrasebook T-1.9 (#24); quick phrases T-1.10 (#25); settings T-1.11 opened as #26; this progress file added |
