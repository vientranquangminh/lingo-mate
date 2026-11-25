# 06 — Feature Details & Acceptance Criteria

Status: Draft v0.1. Format: user stories (US) + acceptance criteria (AC) in Given/When/Then. "Reference device" = doc 01 §10 A-1. Latency is measured as in doc 07 §5.

---

## F-01 Onboarding & language setup

- US-01.1 As a new user, I want to choose my language and the languages I talk with, so the app is ready for my situations.
- US-01.2 As a privacy-conscious user, I want to know what the app does with my voice before granting access.

| AC | Criteria |
|----|----------|
| AC-01.1 | Given first launch, When the app opens, Then the welcome screen shows 3 value props and the privacy promise ("Audio is not saved") with Continue. |
| AC-01.2 | Given the "I speak" step, Then the device language is preselected if it is in the capability matrix, else English. |
| AC-01.3 | Given the "I talk with" step, Then wave-1 languages are listed first, multi-select is allowed (≥ 1 required), and each language shows badges for Offline / Live availability from the capability matrix. |
| AC-01.4 | Given selected languages, When the pack step shows, Then it lists download size per language, a Wi-Fi recommendation, and "Download" / "Later"; choosing Later still reaches Home. |
| AC-01.5 | Given onboarding is completed, Then it never shows again on launch, and Settings → "Run setup again" restarts it. |
| AC-01.6 | Given onboarding, Then no runtime permission prompt is shown; mic permission is requested only when starting the first session, preceded by an explainer screen. |
| AC-01.7 | Given the user denies mic permission twice, When they start a session, Then an explainer with "Open settings" deep link is shown. |

## F-02 Conversation mode

- US-02.1 As a traveller, I want to tap my side and speak, so the other person reads and hears my words in their language.
- US-02.2 As a user, I want the app to detect who is speaking so we don't have to tap every time.
- US-02.3 As a user, I want to save or replay a useful line instantly.

| AC | Criteria |
|----|----------|
| AC-02.1 | Given languages A (user) and B (partner), When Conversation opens, Then the top half is rotated 180° and labelled in B, the bottom half in A, and the engine chip is visible at the divider. |
| AC-02.2 | Given tap-to-talk, When the user taps their mic and speaks then stops for ≥ 600 ms, Then their original text appears on their half and the translation appears large on the partner half. |
| AC-02.3 | Given Standard engine on the reference device with good network, Then end-of-utterance → translation text is p50 ≤ 2.5 s and p90 ≤ 4 s over the benchmark set. |
| AC-02.4 | Given TTS output is on, When a translation arrives, Then it is spoken in the target language, and mic segments are not emitted while TTS is speaking (+150 ms tail) — no self-translation loop occurs in a 10-turn test. |
| AC-02.5 | Given auto mode, When either person speaks, Then the utterance is assigned to A or B by language detection limited to [A, B], with ≥ 90% correct side on the benchmark conversation clips. |
| AC-02.6 | Given an utterance bubble, When long-pressed, Then actions Replay, Copy, Save to phrasebook, Show large appear; Save completes in ≤ 2 taps and shows a confirmation. |
| AC-02.7 | Given the network drops mid-session and offline packs for A and B are installed, Then the next utterance is translated by Offline, the engine chip changes, and a toast says the app switched to Offline. |
| AC-02.8 | Given the network drops and packs are missing, Then a banner explains translation is paused and offers "Download packs" (when online) — no crash, captured text is kept. |
| AC-02.9 | Given Live engine selected (dev flavor), When the user speaks, Then translated audio plays and both transcripts appear; two-way works via two sessions (pending OQ-4 — if rejected, Live is disabled for Conversation and this AC is removed). |
| AC-02.10 | When the user taps Stop or leaves the screen, Then the session is saved (F-07) with duration and engine summary. |

## F-03 Listen mode

- US-03.1 As a student/tourist, I want continuous captions of a speaker in my language.

| AC | Criteria |
|----|----------|
| AC-03.1 | Given source language L and target = user language, When Start is tapped, Then captions stream as a list with original (secondary style) and translation (primary style). |
| AC-03.2 | Given captions are auto-scrolling, When the user scrolls up, Then auto-scroll pauses and a "Jump to live" button appears; tapping it resumes. |
| AC-03.3 | Given "Keep screen on" enabled, Then the screen does not sleep during the session. |
| AC-03.4 | Given a monologue longer than 8 s without pause, Then it is cut at the nearest pause > 250 ms (or hard cut at 8 s) and captions keep flowing. (Was 15 s; lowered for latency, owner feedback 2026-11-25.) |
| AC-03.5 | Given font size slider changes, Then caption text resizes immediately and persists for next sessions. |
| AC-03.6 | Given the session is paused, Then mic capture stops (indicator off) and no usage is counted. |

## F-04 Meeting mode with floating captions

- US-04.1 As a professional, I want floating captions of my laptop meeting over any app on my phone.
- US-04.2 As a user, I want the captions to keep running when my screen is off or I switch apps.

| AC | Criteria |
|----|----------|
| AC-04.1 | Given first Meeting use, Then a setup card explains phone placement and a consent reminder, with "Don't show again". |
| AC-04.2 | Given overlay permission not granted, When starting Meeting, Then an explainer leads to the system overlay settings; if still denied, Meeting runs with in-app captions only and says so. |
| AC-04.3 | Given Meeting started, Then a foreground notification "Translating meeting" with Stop and Open actions is shown for the whole session. |
| AC-04.4 | Given the overlay bubble, Then it shows the last 2–3 translated lines, can be dragged anywhere, tap expands to ~8 lines, and position persists between sessions. |
| AC-04.5 | Given a line in the overlay, When long-pressed, Then it is saved to the phrasebook with a small confirmation. |
| AC-04.6 | Given the app is backgrounded or the screen turns off, Then capture and captions continue (verified for 30 minutes on the reference device without the service being killed). |
| AC-04.7 | Given laptop speaker audio at normal volume ~50 cm from the phone, Then Standard caption latency p50 ≤ 3 s and adequacy ≥ 4/5 on the meeting clips of the benchmark set. |
| AC-04.8 | When Stop is pressed (notification, overlay or app), Then capture stops within 1 s, overlay disappears, notification is removed and the session is saved. |
| AC-04.9 | Given a 30-minute session (Standard), Then battery drain ≤ 8% and latency drift between first and last 5 minutes ≤ 1 s. |

## F-05 Translation engines & auto-selection

- US-05.1 As a user, I want the app to choose the best working engine automatically and tell me which one is active.

| AC | Criteria |
|----|----------|
| AC-05.1 | Given any active session, Then the engine chip always shows Offline / Standard / Live with distinct color and icon (doc 08). |
| AC-05.2 | Given preference Auto and online with packs installed, Then Standard is selected; given offline, Offline is selected. |
| AC-05.3 | Given a language whose capability is `offlineTranslate:false`, Then Offline is never selected for it and the picker shows "Needs internet". |
| AC-05.4 | Given 3 consecutive Standard failures within 30 s, Then the selector switches to Offline (if available) and retries Standard after 60 s. |
| AC-05.5 | Given a cloud call returns FAILED_PRECONDITION "User location is not supported", Then cloud engines are disabled for 24 h and a banner explains Offline still works. |
| AC-05.6 | Given the prod flavor in P1, Then Live is not selectable anywhere; given dev flavor, Live is selectable via engine chip and Settings. |
| AC-05.7 | Given the user taps the engine chip, Then a sheet lists engines with availability reasons (e.g. "Download Japanese pack", "No internet", "Live not in your plan") and allows manual pinning for this session. |
| AC-05.8 | Given model names in Remote Config change, Then the next session uses the new model without an app update. |

## F-06 Language packs

| AC | Criteria |
|----|----------|
| AC-06.1 | Given the packs screen, Then each language shows status, ASR model size, translation model size and total storage used. |
| AC-06.2 | Given Wi-Fi-only on and the device on mobile data, When Download is tapped, Then the app asks to allow mobile data once or waits for Wi-Fi. |
| AC-06.3 | Given a download in progress, Then progress % updates at least every 2 s and continues if the user leaves the screen; failures show Retry. |
| AC-06.4 | Given ASR + ML Kit models present, Then the language shows "Ready offline"; if TTS voice is missing, a warning with "Install voice" appears. |
| AC-06.5 | Given a non-English language is downloaded, Then the English ML Kit model is also ensured (pivot). |
| AC-06.6 | When Delete is tapped and confirmed, Then models are removed, storage figure updates, and Offline becomes unavailable for that language. |
| AC-06.7 | Given a language unsupported offline, Then it shows "Not available offline" with no download button. |

## F-07 Sessions & transcripts

| AC | Criteria |
|----|----------|
| AC-07.1 | Given finished sessions, Then history lists them newest first, grouped by day, with mode icon, language pair, duration and first translated line. |
| AC-07.2 | Given a transcript, Then each utterance shows time, side/speaker, original, translation and an engine badge when it differs from the session's main engine. |
| AC-07.3 | Given the search field, When the user types ≥ 2 characters, Then matching utterances across sessions appear within 300 ms for 10,000 utterances. |
| AC-07.4 | When a session is deleted and confirmed, Then it and its utterances are removed from the DB. |
| AC-07.5 | Given Share, Then the transcript is shared as plain text (original + translation per line) via the system share sheet. |
| AC-07.6 | Then no audio files exist in app storage after any session (verified by file-system check in tests). |

## F-08 Phrasebook

| AC | Criteria |
|----|----------|
| AC-08.1 | Given an utterance saved from any screen, Then it appears at the top of the phrasebook with source session link. |
| AC-08.2 | Given a phrase with identical source text and language pair already exists, When saving again, Then no duplicate is created and a toast says "Already in phrasebook". |
| AC-08.3 | Given Add phrase, When the user types a source sentence, Then a translation is proposed by the current engine and is editable before saving. |
| AC-08.4 | Given filters (pair, tag, favorites) and search, Then the list updates within 200 ms for 5,000 phrases. |
| AC-08.5 | Given phrase detail, When Play is tapped on either side, Then TTS speaks it in that language; Show large opens show mode. |
| AC-08.6 | When a phrase is deleted, Then it disappears from lists (soft-deleted in DB) and Undo is available for 5 s. |

## F-09 Quick phrases by situation

| AC | Criteria |
|----|----------|
| AC-09.1 | Given airplane mode, Then all situations and phrases for downloaded/bundled languages display and can be shown in show mode. |
| AC-09.2 | Given a phrase is tapped, Then it is spoken via TTS in the partner language within 500 ms (voice installed) — otherwise show mode opens with a hint to install voice. |
| AC-09.3 | Given a slot template, When the user picks slot values from chips, Then the sentence updates in both languages before speaking. |
| AC-09.4 | Given show mode, Then the translation fills the screen in large type with a rotate-180° button for the partner, and the original below in small type. |
| AC-09.5 | Given star tapped, Then the phrase appears in a Favorites row at the top of the situations screen. |
| AC-09.6 | Given P1 bundle, Then 8 situations exist with ≥ 20 phrases each, translated for all wave-1 languages. |

## F-10 Settings & privacy controls

| AC | Criteria |
|----|----------|
| AC-10.1 | Changing UI language updates all screens immediately without restart. |
| AC-10.2 | Engine preference options: Auto, Prefer Offline, Prefer Standard, Allow Live (dev/P2); the selector honours them (F-05). |
| AC-10.3 | Given "Delete all data" confirmed twice, Then DB, prefs, downloaded models (optional checkbox) and (P2) cloud data are removed and the app returns to onboarding. |
| AC-10.4 | Given analytics consent off, Then no Analytics events are sent (verified with DebugView). |
| AC-10.5 | Licenses page lists open-source licenses and ML Kit attribution. |

## F-11 UI localization

| AC | Criteria |
|----|----------|
| AC-11.1 | All user-facing strings come from ARB files; a lint/test fails on hard-coded strings in `presentation/`. |
| AC-11.2 | Every screen renders in `en` and `vi` at text scale 1.0 and 2.0 without overflow (golden tests). |
| AC-11.3 | Given a fresh install on a phone set to Vietnamese, Then the UI is Vietnamese; on a phone set to an unsupported language (e.g. French), Then the UI is English. |
| AC-11.4 | When the user picks a language in Me → App language or on Welcome, Then every visible screen switches immediately without restart, and the choice survives an app restart. |
| AC-11.5 | Choosing "Phone language" returns to following the device language. |
| AC-11.6 | On Android 13+, the app appears in system Settings → App languages with exactly the supported languages; a change there updates the in-app setting and vice versa. |
| AC-11.7 | Signed in: the choice is saved as `uiLocale` and applied after sign-in on a new device that has no explicit choice yet. |
| AC-11.8 | In Conversation, the partner half's language label and "Tap to speak" hint are in the partner's language for every wave-1 language; other languages fall back to English. |
| AC-11.9 | CI lists untranslated keys (gen-l10n `untranslated-messages-file`) and fails a release build if any `vi` key is missing. |

## F-12 Dev tools & benchmark harness

| AC | Criteria |
|----|----------|
| AC-12.1 | Dev flavor shows a devtools entry; prod flavor has no devtools code reachable (compile-time flag). |
| AC-12.2 | Latency HUD shows per-utterance stage timings (VAD end, ASR done, translation done, TTS start). |
| AC-12.3 | Benchmark runner processes every clip in `test_assets/audio/manifest.json` through each selected pipeline and exports a CSV with clip id, engine, stage latencies, transcript and translation. |
| AC-12.4 | Engine switcher can force any engine regardless of auto-selection. |

---

## F-13 Account: sign-in, profile, sync & account deletion (P2)

- US-13.1 As a new user, I want to use the app without creating an account, so I can try it immediately.
- US-13.2 As a returning user on a new phone, I want to sign in and get my phrases and plan back.
- US-13.3 As a user, I want to see my account, plan and usage in one place.
- US-13.4 As a user, I want to delete my account and data whenever I choose.

| AC | Criteria |
|----|----------|
| AC-13.1 | First launch of a P2 build signs in anonymously without UI; offline, quick phrases, local phrasebook and Standard free quota work without any sign-in screen. |
| AC-13.2 | Given the sign-in screen (S-24), Then it offers Continue with Google, Continue with email and "Later", plus a one-line reason specific to the entry point (sync / Live / purchase / restore). |
| AC-13.3 | Given an anonymous user with local data, When they continue with Google (Credential Manager sheet), Then the anonymous account is linked (same uid) and all local data remains. |
| AC-13.4 | Given the Google identity already belongs to another account, When the user signs in, Then the app signs in to that account and asks whether to merge this device's local phrases; choosing Merge imports them without duplicates (AC-08.2 rule). |
| AC-13.5 | Given Continue with email, When the user enters a valid address, Then a sign-in link is sent; opening the link on the same device signs them in; opening it on another device asks to confirm the email first. Invalid/expired links show a clear error and "Send again". |
| AC-13.6 | Given an anonymous user taps Start on a Live session (incl. the free trial), Then the sign-in screen opens first; after sign-in the session starts automatically. |
| AC-13.7 | Given a signed-in user, Then the Me tab (S-17) shows the account card (initials or photo, name, email, provider), plan card with status and usage mini-bars, stats (hours translated, phrases saved, review streak) and the settings list. |
| AC-13.8 | Given an anonymous user, Then the account card shows "Sign in to sync and use Live" and opens S-24. |
| AC-13.9 | With sync on, a phrase created on device 1 appears on device 2 within 10 s while both online; concurrent edits resolve by latest `updated_at`; deletes propagate. |
| AC-13.10 | Transcripts are not uploaded unless "Sync transcripts" is enabled. |
| AC-13.11 | When the user signs out, Then the app asks Keep / Remove device data, applies the choice, and continues as a new anonymous user; signing in again restores cloud data. |
| AC-13.12 | Given Delete account, Then the user must re-authenticate and confirm; on success the Auth user, `users/{uid}` subtree, usage records, live token records and RevenueCat customer are deleted, local data is wiped, and the app returns to onboarding. |
| AC-13.13 | Given an active Google Play subscription at deletion time, Then the confirmation screen warns that the subscription continues until cancelled in Google Play and offers the Play management link. |
| AC-13.14 | The web deletion page loads without error, names the app, and lets a user submit a deletion request without the app installed; the request is processed by the same deletion routine. |

## F-14 Usage limits & usage meter (P2)

| AC | Criteria |
|----|----------|
| AC-14.1 | Given no active window, When the user starts using an engine, Then a 5-hour window starts at that moment and resets exactly 5 h later; the weekly window starts at first use and resets 7 days later. |
| AC-14.2 | Given Live remaining < 60 s, Then `issueLiveToken` returns `allowed:false` with `resetAt`, and the app falls back to Standard and shows the usage sheet. |
| AC-14.3 | Given a token is issued, Then the block (≤ 600 s, ≤ remaining) is reserved server-side before the token is returned; the session ends when the token expires and a new token is requested. |
| AC-14.4 | Given a session ends cleanly after using 130 s of a 600 s block, Then `reportLiveUsage` refunds 470 s exactly once; a second report for the same token is ignored. |
| AC-14.5 | A client cannot write `usage/live` or `liveTokens` (rules tests). |
| AC-14.6 | Given 80% of any cap used, Then a one-time warning appears; at 100% the active cloud engine stops at the next utterance boundary. |
| AC-14.7 | The usage sheet shows per-engine bars for the 5-hour window and the week, with local-time reset times. |
| AC-14.8 | Changing `quota_limits` in Remote Config changes enforcement (server and client) without an app update. |
| AC-14.9 | `issueLiveToken` called by an anonymous user returns `allowed:false, reason:'sign_in_required'` and issues no token; the free Live trial is tracked per signed-in account, so reinstalling the app does not reset it. |

## F-15 Subscription: paywall, manage subscription, Live top-ups & purchase history (P2)

- US-15.1 As a user, I want to compare plans and buy one in a few taps.
- US-15.2 As a subscriber, I want to see what I pay, when it renews and what I have left.
- US-15.3 As a subscriber with a payment problem, I want to know before I lose access.

| AC | Criteria |
|----|----------|
| AC-15.1 | Paywall shows plans from RevenueCat offerings with localized store prices (never hard-coded). |
| AC-15.2 | Purchase requires a signed-in (non-anonymous) account; success unlocks the entitlement in the app within 5 s and updates `users/{uid}.plan` via webhook. |
| AC-15.3 | Restore purchases works on a fresh install with the same Google account. |
| AC-15.4 | A Live top-up purchase adds its seconds to the top-up balance used after plan allowance is exhausted. |
| AC-15.5 | With `ff_paywall=false`, no paywall or Manage plan entry point is visible. |
| AC-15.6 | Given an active renewing subscription, Then Manage subscription (S-25) shows plan, billing period, store price and "Renews on {date}". |
| AC-15.7 | Given `willRenew=false` / `unsubscribeDetectedAt` set while the entitlement is active, Then S-25 shows "Pro until {date}" and a Resubscribe action. |
| AC-15.8 | Given the entitlement is active and `billingIssueDetectedAt` is set, Then S-25, the Me plan card and a one-time Home banner show the payment-issue state with the grace-period end date and an Update payment action that opens Google Play. |
| AC-15.9 | Given the entitlement became inactive after a billing issue, Then S-25 shows the paused/expired state, cloud quotas fall back to Free, and offline features keep working. |
| AC-15.10 | "Cancel or change payment on Google Play" opens `managementURL`; if it is null (no purchase yet) the action is hidden. |
| AC-15.11 | Benefits block shows Standard allowance, Live minutes left this month and top-up balance, matching the Usage sheet (S-18) values. |
| AC-15.12 | Purchase history lists subscription renewals and top-ups (date, product, store price) from `users/{uid}/transactions`, newest first; empty state "No purchases yet". |

## F-16 Spaced-repetition review (P2)

| AC | Criteria |
|----|----------|
| AC-16.1 | Due cards are shown one by one; answers Again/Hard/Good/Easy update ease/interval per SM-2 (unit-tested against reference values). |
| AC-16.2 | Review works offline. |
| AC-16.3 | Opt-in daily reminder fires at the chosen time when cards are due. |

## F-17 Post-session review (P2)

| AC | Criteria |
|----|----------|
| AC-17.1 | After a session with ≥ 3 user utterances, the user can request a review; result lists ≤ 5 items with original, improved version and a one-line reason. |
| AC-17.2 | Each item can be saved to the phrasebook in one tap. |
| AC-17.3 | Offline: the button is disabled with "Needs internet". |

## F-18 Glossary (P2)

| AC | Criteria |
|----|----------|
| AC-18.1 | User can create sets and terms; the active set is chosen per session. |
| AC-18.2 | With a set active, a term spoken in an utterance is translated with the preferred translation in ≥ 90% of benchmark glossary clips (Standard). |

## F-19 Suggested replies (P2)

| AC | Criteria |
|----|----------|
| AC-19.1 | "Suggest reply" returns 3 replies in the partner language with back-translation within 3 s p50. |
| AC-19.2 | Tapping a reply speaks it (Conversation) or copies it (Meeting). |

## F-20 Session summary & action items (P2)

| AC | Criteria |
|----|----------|
| AC-20.1 | For Meeting/Listen sessions ≥ 3 min, Summarize produces summary, key terms and action items in the user language, stored with the session. |
| AC-20.2 | Summary is shareable as text. |

## F-21 Media capture mode (P3)

| AC | Criteria |
|----|----------|
| AC-21.1 | After MediaProjection consent, audio from a browser video is captioned. |
| AC-21.2 | If the captured stream is silent for 10 s while media plays, the app explains the source app may block capture. |

## F-22 Roleplay practice (P3)

| AC | Criteria |
|----|----------|
| AC-22.1 | User picks a situation; the partner opens the conversation and replies in the target language; the user can answer by voice or text and receive feedback. |

## F-23 Home widget & Quick Settings tile (P3)

| AC | Criteria |
|----|----------|
| AC-23.1 | Widget starts Conversation in 1 tap and shows up to 4 favorite quick phrases. |
| AC-23.2 | QS tile starts/stops Meeting captions. |

## F-24 Global rollout (P3)

| AC | Criteria |
|----|----------|
| AC-24.1 | UI available in all wave-1 languages; store listing localized for the same. |
| AC-24.2 | In a region where Gemini is blocked (simulated by forcing the error), onboarding and banners explain Offline-only clearly. |
