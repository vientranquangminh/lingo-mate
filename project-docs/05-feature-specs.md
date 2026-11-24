# 05 — Feature Specs

Status: Draft v0.1. Acceptance criteria live in doc 06. Screen IDs (S-xx) refer to doc 08.

## Feature catalogue

| ID | Feature | Phase | Priority | Screens |
|----|---------|-------|----------|---------|
| F-01 | Onboarding & language setup | P1 | Must | S-01, S-02, S-03 |
| F-02 | Conversation mode (face-to-face) | P1 | Must | S-05 |
| F-03 | Listen mode (one-way captions) | P1 | Must | S-06 |
| F-04 | Meeting mode with floating captions | P1 | Must | S-07, S-08 |
| F-05 | Translation engines & auto-selection | P1 (Live prod in P2) | Must | engine chip, S-17 |
| F-06 | Language packs (offline downloads) | P1 | Must | S-16 |
| F-07 | Sessions & transcripts | P1 | Must | S-09, S-10 |
| F-08 | Phrasebook | P1 | Must | S-11, S-12 |
| F-09 | Quick phrases by situation | P1 | Must | S-13, S-14, S-15 |
| F-10 | Settings & privacy controls (inside the Me / Profile tab) | P1 | Must | S-17 |
| F-11 | UI localization (English default, + vi) and App language setting | P1 | Must | S-01, S-17 |
| F-12 | Dev tools & benchmark harness | P0 | Must (dev only) | S-23 |
| F-13 | Account: sign-in, profile, sync & account deletion | P2 | Must | S-24, S-17 |
| F-14 | Usage limits & usage meter | P2 | Must | S-18 |
| F-15 | Subscription: paywall, manage subscription, Live top-ups & purchase history | P2 | Must | S-19, S-25, S-18 |
| F-16 | Spaced-repetition review | P2 | Should | S-20 |
| F-17 | Post-session review ("how a native would say it") | P2 | Should | S-21 |
| F-18 | Glossary (project terms) | P2 | Should | S-22 |
| F-19 | Suggested replies | P2 | Could | S-05, S-07 |
| F-20 | Session summary & action items | P2 | Could | S-10 |
| F-21 | Media capture mode | P3 | Could | S-06 variant |
| F-22 | Roleplay practice | P3 | Could | new |
| F-23 | Home widget & Quick Settings tile | P3 | Could | widget |
| F-24 | Global rollout (wave-1 everywhere, store localization, regional pricing) | P3 | Should | — |

Priority: Must = phase cannot ship without it · Should = expected, can slip one phase · Could = nice to have.

---

## F-01 Onboarding & language setup
**Purpose**: get a new user to a working first translation in < 60 s.
**Flow**: Welcome (value props, privacy promise) → "I speak" (UI language defaults to device) → "I usually talk with" (multi-select, wave-1 first) → offer offline packs for chosen languages (Wi-Fi recommended, sizes shown) → mic permission explainer → Home.
**Rules**: permissions requested only when first needed (mic at first session, overlay at first Meeting, notifications at first background session). Skippable pack download. Re-runnable from Settings.
**Out of scope**: account creation (P2).

## F-02 Conversation mode
**Purpose**: two people facing each other talk in two languages.
**UX**: split screen; bottom half for user (lang A), top half rotated 180° for partner (lang B). Each half: big mic button, latest original (small) + translation (large). Modes: **tap-to-talk per side** (default) and **auto** (VAD + language auto-detect between A/B). Translation spoken by TTS toward the other person (toggle). Engine chip at the center divider. Tap any bubble → actions: replay audio (TTS), copy, save to phrasebook, show large.
**Engines**: Offline / Standard / Live (two-session) per F-05.
**Echo**: half-duplex gating while TTS speaks.
**Saves** a session (F-07) on stop.

## F-03 Listen mode
**Purpose**: understand a speaker (lecture, guide, announcement, video in the room).
**UX**: source language picker (or auto), target = user language. Continuous captions list (original small/grey, translation large), auto-scroll with "jump to live" when user scrolls up. Keep screen on option. Pause/resume. Font size slider.
**Engines**: Standard default; Offline when offline; Live (captions + optional audio in earphones) if enabled.

## F-04 Meeting mode with floating captions
**Purpose**: follow an online meeting playing on a laptop, using the phone mic.
**UX**: setup card explains "Put your phone near the laptop speaker" + consent reminder. Start → foreground service + notification (Stop, Open). Floating caption bubble over other apps: last 2–3 translated lines, drag to reposition, tap to expand/collapse, long-press a line to save. In-app view mirrors full transcript with speaker turns (unlabelled "Speaker" changes on long pauses; no diarization in P1).
**Engines**: Standard default (cheap); Live only when the user turns it on.
**Platform**: FGS type microphone; overlay permission flow; graceful fallback to in-app captions.
**Out of scope**: capturing call audio directly (blocked); joining meetings as a bot.

## F-05 Translation engines & auto-selection
**Purpose**: always pick the best engine available; never hide which one runs.
**Rules**: selection algorithm doc 03 §7; fallback chain Live → Standard → Offline; user can pin an engine in Settings and per session via engine chip. Live requires `ff_live_enabled` and (P2) quota + token. Region block handling. Engine chip colors/labels in doc 08.
**P1**: Live works in dev flavor with API key; hidden in prod builds until P2.

## F-06 Language packs
**Purpose**: manage offline models (ML Kit translation + ASR) per language.
**UX**: list of languages with status (Not downloaded / Downloading x% / Ready / Update available / Not available offline), size per component, total storage used, delete. Wi-Fi only toggle. Packs suggested from onboarding choices.
**Rules**: a language is "offline-ready" only when ASR model + ML Kit model are both present (and TTS voice for spoken output — warn if missing). English is required as pivot for ML Kit non-English pairs → auto-include.

## F-07 Sessions & transcripts
**Purpose**: keep what was said, searchable.
**UX**: history list grouped by date (mode icon, languages, duration, engine summary, first line). Transcript view: utterances with time, speaker side, original + translation, engine badge per utterance (e.g. "Offline fallback"), actions (save phrase, copy, share text, delete session). Search across all transcripts (FTS). Rename session.
**Rules**: stored locally only (P1). Auto title from first translated sentence. No audio stored.

## F-08 Phrasebook
**Purpose**: personal collection of useful sentences.
**UX**: list with search, filter by language pair and tag, favorites; phrase detail: source/target, play (TTS) both sides, note, tags, source session link, "show large". Add manually (type → auto-translate with current engine, editable).
**Rules**: save from any utterance in ≤ 2 taps; duplicates (same source text + pair) merge with a toast. Soft delete (for later sync).

## F-09 Quick phrases by situation
**Purpose**: speak common sentences instantly, even offline.
**Content**: bundled situation packs (P1: Airport, Hotel, Restaurant, Taxi/Directions, Shopping, Emergency/Health, Small talk, Meeting basics) — canonical English + translations for wave-1 languages, generated with LLM and reviewed. Slot templates: "Can I have {n} {item}, please?" with chips for slot values.
**UX**: situations grid → phrase list (in user language, translation below) → tap = speak via TTS; long-press = show mode (full-screen large text, rotate for partner); star = favorite; "Add to phrasebook".
**Rules**: works fully offline (texts bundled; TTS offline voice if installed, else show-mode only).

## F-10 Settings & privacy controls
Lives in the **Me** tab (S-17), below the account card, plan card and stats (F-13, F-15). In P1 (no login) the Me tab shows a "Sign in — coming soon" placeholder instead of the account card, or hides it.
UI language; default languages; engine preference (Auto / prefer Offline / prefer Standard / allow Live); TTS voice/speed; caption font size; keep screen on; Wi-Fi-only downloads; analytics/crash reporting consent; "Delete all data"; licenses/attributions (ML Kit); about; (P2) account, sync, plan.

## F-11 UI localization & app language
- **English is the default and source language** (D-22). Every string is written in English first; `app_en.arb` is the template ARB, other ARBs are translations. All user-facing strings go through `AppLocalizations`; numbers/dates via `intl`.
- Launch UI languages: English and Vietnamese (`supportedLocales` = en, vi). More arrive in P3 (F-24); adding one = a new ARB + store listing, no code change.
- First launch: use the phone's language if supported, otherwise English.
- **App language** setting in Me (S-17) and as a selector on Welcome (S-01): "Phone language (default)", then each supported language by its endonym (English, Tiếng Việt). Applies immediately, no restart. Stored in prefs, and in `users/{uid}.uiLocale` when signed in.
- Android 13+: supported locales declared in `res/xml/locales_config.xml` (`android:localeConfig`), so the app shows in system Settings → App languages; in-app and system settings stay in sync (platform channel to `LocaleManager` on API 33+).
- Partner-facing strings (≈ 5: partner-half language label, "Tap to speak", show-mode hint) are bundled for every wave-1 language, so the partner reads their own language even where the full UI isn't translated; fallback English.
- UI language is independent of the translation languages (My languages).
- Pseudo-locale test for overflow.

## F-12 Dev tools & benchmark harness (dev flavor only)
Engine switcher; latency HUD (VAD end → ASR done → translation done → TTS start); audio source/NS/AGC toggles; **Benchmark runner**: plays/feeds files from `test_assets/audio/` through each pipeline and exports CSV (clip, engine, latency stages, transcript, translation) for scoring (doc 07 §5); Remote Config override viewer; fake quota controls.

## F-13 Account: sign-in, profile, sync & account deletion (P2)
**Purpose**: let people keep their data and plan across devices — without forcing an account on anyone who only needs offline translation.

**Sign-in (S-24)**
- Methods: **Continue with Google** (Credential Manager), **Continue with email** (passwordless email link). No passwords stored by us. Apple sign-in only when iOS starts (OQ-13).
- **Later** = keep using the app with an anonymous Firebase account. Offline mode, quick phrases, phrasebook (local) and Standard free quota work without sign-in.
- Sign-in is requested when the user: turns on sync, starts **any Live session (incl. the free trial)**, buys or restores a plan, or opens Me → account card. Each entry point explains why in one line.
- Linking: the anonymous account is upgraded in place (same uid, local data kept). If the Google/email identity already belongs to another account, sign in to that account and offer to merge this device's local phrases into it.

**Profile — Me tab (S-17)**
- Account card (avatar initials/photo, name, email, provider) → account details: display name edit, sign out, delete account.
- Plan card: plan name + billing period, status (active / cancels on date / payment issue / expired), usage mini-bars (Live this month, Standard this week) → Usage sheet (S-18); **Manage plan** → S-25.
- Stats: hours translated, phrases saved, review streak (computed locally; synced when signed in).
- Settings list (F-10): My languages, App language (F-11), Offline packs, Translation & voice, Privacy & data (sync toggle, analytics, delete data), Help & feedback, Sign out.

**Sync**: phrasebook, tags, SRS, glossary, profile/stats (transcripts only if "Sync transcripts" is on). Last-write-wins per record using `updated_at`; soft deletes propagate.

**Sign out**: asks "Keep this device's data?" (Keep / Remove). Afterwards the app continues as a new anonymous user; cloud data stays in the account for next sign-in.

**Account deletion** (Google Play policy: in-app path **and** a web link)
- In app: Me → account → Delete account → re-authenticate → confirm. Deletes Auth user, Firestore data, usage records and the RevenueCat customer; wipes local data; reminds the user that an active Google Play subscription must be cancelled in Play (link via `managementURL`).
- Web: a page on Firebase Hosting where a user can request deletion without reinstalling the app; linked from the Data safety form, the privacy policy and the app.

## F-14 Usage limits & usage meter (P2)
5-hour window + weekly cap per engine (and monthly allowance / top-up balance for Live). Server enforcement for Live (`issueLiveToken`), client for Standard. Usage sheet with bars and reset times; warnings at 80% and 100%; at exhaustion the session continues on the next allowed engine at an utterance boundary. Limits from Remote Config `quota_limits` (doc 03 §10).

## F-15 Subscription: paywall, manage subscription, Live top-ups & purchase history (P2)
**Paywall (S-19)**: RevenueCat offerings; plan comparison (Free / Pro Lite / Pro), monthly/yearly toggle, Live top-up packs, restore purchases, terms/privacy links. Entry points: usage exhausted, Live toggle, Usage sheet, Manage plan → Change plan. Prices come from the store (never hard-coded); TBD (OQ-2). Hidden behind `ff_paywall`.

**Manage subscription (S-25)** — reached from Me → plan card → Manage plan:
- Status card: plan + period, store price, state and the key date.
- States (from RevenueCat CustomerInfo):

| State | How detected | What the screen shows |
|-------|--------------|-----------------------|
| Free | no active entitlement | Free limits + "See plans" |
| Active, renewing | entitlement active, `willRenew = true` | "Renews on {date}" |
| Active, cancelled | entitlement active, `unsubscribeDetectedAt` set / `willRenew = false` | "Pro until {date}" + "Resubscribe" |
| Payment issue (grace period) | entitlement active + `billingIssueDetectedAt` set | Amber banner "Update payment before {date}" + **Update payment** (opens Play) |
| Expired / on hold | entitlement inactive after a billing issue | "Pro paused — update payment in Google Play" |

- Benefits block: Standard allowance, Live minutes left this month, top-up balance.
- Actions: Update payment (only in payment-issue state), Buy Live minutes, Change plan (→ S-19), Restore purchases, "Cancel or change payment on Google Play" (opens `managementURL`).
- Purchase history: subscriptions and top-ups with date and store price (from `users/{uid}/transactions`, written by the RevenueCat webhook).
- Cancelling happens only in Google Play; the app never cancels on the user's behalf.

## F-16 Spaced-repetition review (P2)
Daily review of phrasebook cards (both directions), SM-2-style scheduling (Again/Hard/Good/Easy), streak counter, reminder notification (opt-in). Offline.

## F-17 Post-session review (P2)
After a session (opt-in per session, online): LLM lists up to 5 user utterances with "a native speaker would say…", short reason, one-tap save to phrasebook. Uses `model_text_review`. Counted as Standard usage (small).

## F-18 Glossary (P2)
Glossary sets (e.g. per client/project): term + preferred translation + note. Selected set is injected into Standard prompts and used as ASR prompt hint where the ASR lib supports it.

## F-19 Suggested replies (P2)
In Conversation/Meeting, a "Suggest reply" button generates 3 short replies in the partner's language with back-translation, based on the last 5 utterances. Tap = speak (Conversation) or copy (Meeting).

## F-20 Session summary & action items (P2)
For Meeting/Listen sessions: summary (in user language), key terms, action items; stored with the session; shareable text.

## F-21 Media capture mode (P3)
Translate audio playing on the phone (YouTube, podcasts, webinars in a browser) via AudioPlaybackCapture; explain that calls can't be captured and some apps block capture.

## F-22 Roleplay practice (P3)
Situation-based practice partner (text first, then voice) using the user's phrasebook and situations; feedback on phrasing.

## F-23 Home widget & Quick Settings tile (P3)
Widget: start Conversation / favorite quick phrases. QS tile: start Meeting captions.

## F-24 Global rollout (P3)
Wave-1 UI languages, store listing per locale, regional price groups (doc 09 draft), capability matrix updates, region-block messaging verified per market.
