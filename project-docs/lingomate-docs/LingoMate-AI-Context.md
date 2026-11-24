# Lingo Mate — full project context (all docs in one file)

Generated 2026-11-24 from the Lingo Mate project package (v0.1). Use this file to give an AI assistant the complete project context.

How to read it:
- Each section below is one file of the package, starting with a line `===== FILE: <path> =====`.
- Visual design: read it from Figma https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k (per-screen frame links in design/README.md).
- Decisions in docs/09 are settled; open questions (OQ-x) are not decided yet.
- IDs: F-xx feature, AC-xx.y acceptance criterion, S-xx screen, T-x.y plan task, D-xx decision, OQ-xx open question.

Files included:
- README.md
- CLAUDE.md
- docs/00-preparation.md
- docs/01-project-spec.md
- docs/02-project-plan.md
- docs/03-technical-design.md
- docs/04-integrations.md
- docs/05-feature-specs.md
- docs/06-feature-details-acs.md
- docs/07-test-plan.md
- docs/08-design-system.md
- docs/09-decisions-and-open-questions.md
- design/README.md
- assets/brand/README.md
- assets/icons/README.md


===== FILE: README.md =====

# Lingo Mate — project package

Lingo Mate is an Android-first Flutter app for live speech translation (face-to-face conversation, listening, online meetings), with a phrasebook and quick phrases. This package holds everything needed to build it.

- **Design (Figma, source of truth for visuals):** https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k
- **Status:** Draft v0.1 · last updated 2026-11-24

## What's inside

| Path | What |
|------|------|
| `CLAUDE.md` | Entry point for Claude Code: reading order, hard rules, stack, commands, Definition of Done |
| `docs/00-preparation.md` … `docs/09-decisions-and-open-questions.md` | Preparation, project spec, plan, technical design, integrations, feature specs, acceptance criteria, test plan, design system, decisions & open questions |
| `design/` | Screen exports of the Figma design: PNG per screen, HTML sources, gallery (`index.html`), PDF (`LingoMate-UI-Design.pdf`), per-screen Figma links in `design/README.md` |
| `assets/brand/` | App icon (adaptive layers, Play icon, notification icon) + Flutter setup |
| `assets/icons/` | 79 in-app SVG icons + inventory |
| `LingoMate-AI-Context.md` | All text docs merged into one file — upload this to any AI assistant (ChatGPT, Gemini, Claude…) to give it the full project context |

## How to use

- **Design:** give the AI the Figma link above (it reads frames through the Figma MCP server); per-screen links are in `design/README.md`.
- **Claude Code / coding AI:** copy `CLAUDE.md`, `docs/`, `design/` and `assets/` into the repo root, connect the Figma MCP server, then follow `docs/00-preparation.md` §9.
- **Any other AI chat:** upload the separate docs (`CLAUDE.md`, `docs/00…09`), or the single merged `LingoMate-AI-Context.md` if the tool limits the number of files, plus the Figma link.
- **People:** open `design/LingoMate-UI-Design.pdf` or the Figma link.


===== FILE: CLAUDE.md =====

# CLAUDE.md — Lingo Mate

Lingo Mate is an Android-first Flutter app for **live speech translation**: face-to-face conversations (online or offline), one-way listening (lectures, tours), and online meetings heard through the phone mic, with a personal phrasebook, quick phrases by situation, and learning features built from the user's own conversations.

The app is called **Lingo Mate** (D-24). The package id is `com.lingomate.app` (D-25); the final store-name/trademark check is still open (OQ-7).

## Read these first (in order)

| # | File | What it gives you |
|---|------|-------------------|
| 1 | `docs/01-project-spec.md` | Why the app exists, scope, goals/non-goals, constraints |
| 2 | `docs/09-decisions-and-open-questions.md` | Decisions already made (do not reopen) and open questions |
| 3 | `docs/03-technical-design.md` | Architecture, modules, data model, pipelines, quota engine |
| 4 | `docs/04-integrations.md` | Every external service: setup, config, limits, failure modes |
| 5 | `docs/05-feature-specs.md` | Feature catalogue (IDs F-01…F-24), phase, priority |
| 6 | `docs/06-feature-details-acs.md` | User stories + acceptance criteria per feature |
| 7 | `docs/07-test-plan.md` | Test strategy, spike benchmark protocol, release gates |
| 8 | `docs/08-design-system.md` | Tokens, components, screen specs, navigation |
| 9 | Figma: https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k (per-screen frame links in `design/README.md`) | The visual design. Read the screen's Figma frame (Figma MCP `get_design_context` / `get_screenshot`) before building it. `design/screens/*.png` and `design/html/` are offline copies to use if Figma is unreachable or its read quota runs out |
| 10 | `docs/02-project-plan.md` | Phases, milestones, task order |
| 11 | `docs/00-preparation.md` | Accounts, tools, secrets, devices (owner's checklist) |

## How to work on this repo

1. Work phase by phase as in `docs/02-project-plan.md`. Do not start a later phase's features unless the owner asks.
2. Every task maps to a feature ID (F-xx) or a plan task ID (T-x.y). Reference it in branch names and commits: `feat(F-02): split-screen conversation view`.
3. A feature is done only when all its acceptance criteria in `docs/06-feature-details-acs.md` pass and its tests exist (see Definition of Done below).
4. If a spec is ambiguous or contradicts another doc, stop and ask the owner. Do not guess on anything listed in the "Open questions" section of doc 09.
5. Decisions in doc 09 are settled. If you believe one is wrong, explain why and wait for the owner; do not silently diverge.
6. Prefer small, reviewable PRs (one feature slice per PR).

## Hard rules

- **No secrets in release builds.** The Gemini API key is allowed only in the `dev` flavor via `--dart-define-from-file=.env.dev`. Env files are plain `KEY=VALUE` files in the project root (`.env.dev` dev, `.env.staging` staging, `.env` production), never JSON. Production Live sessions use ephemeral tokens from the `issueLiveToken` Cloud Function. CI must fail if a release build contains `AIza` strings.
- **No audio is persisted by default.** Audio buffers live in memory only. Transcripts are stored locally (Drift). Cloud sync is opt-in.
- **Never log transcript text or audio** to Analytics, Crashlytics or console in release builds.
- **Model names, quotas, feature flags and the language capability matrix come from Remote Config** with safe defaults in code. Never hard-code a model name outside `lib/core/config/remote_defaults.dart`.
- **All engines sit behind interfaces** (`SpeechRecognizerEngine`, `TextTranslatorEngine`, `SpeechSynthesizerEngine`, `LiveInterpreterEngine`). UI code never talks to a plugin or SDK directly.
- **Third-party apps cannot capture call audio** (Zoom/Meet/Teams use `USAGE_VOICE_COMMUNICATION`). Meeting mode uses the microphone. Do not try to work around this.
- Android only for now. Do not add iOS-specific code paths unless asked; keep code platform-agnostic where it costs nothing.
- Ship 64-bit ABIs only (`arm64-v8a`, `x86_64`): ML Kit does not support 32-bit.
- **Never require sign-in for offline features.** Sign-in gates only Live, purchases/restore and sync (D-17, D-18). Any build that lets users create an account must also ship in-app + web account deletion (D-19).
- Plan and quota state come from the server (Firestore, written by Functions/webhook), never from client-side flags.

## Stack (summary — details in doc 03)

- Flutter (stable channel), Dart 3, Android minSdk 26, target/compile latest stable SDK
- State/DI: Riverpod (with code generation) · Routing: go_router · Models: freezed + json_serializable
- Local DB: Drift (SQLite) · Prefs: shared_preferences
- Firebase: AI Logic (Gemini), App Check, Remote Config, Crashlytics, Analytics; Auth + Firestore + Cloud Functions from Phase 2
- On-device: ML Kit Translation, on-device ASR (whisper.cpp or sherpa-onnx — chosen in the Phase 0 spike), flutter_tts
- Cloud speech: Gemini Live Translate (`gemini-3.5-live-translate-preview`) over the Live API WebSocket
- Subscriptions (Phase 2): RevenueCat over Google Play Billing
- Icons: custom SVG set in `assets/icons/` via `flutter_svg` (don't mix Material icons); launcher/Play/notification icons in `assets/brand/` (see each folder's README)

## Commands

```bash
# run
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=.env.dev
flutter run --flavor production -t lib/main.dart --dart-define-from-file=.env

# quality
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter test integration_test -d <device-id>

# functions (Phase 2)
cd functions && npm run build && firebase emulators:start
```

## Definition of Done (every feature)

- [ ] All ACs for the feature in doc 06 pass on a physical mid-range Android device
- [ ] Unit tests for domain/application logic; widget tests for each screen state (loading / empty / content / error)
- [ ] Strings added to `app_en.arb` first (English is the source language, D-22) and translated to `vi`; no hard-coded user-facing text
- [ ] Works in light and dark theme; TalkBack labels on interactive elements; text scales to 200% without clipping
- [ ] `flutter analyze` clean; no new warnings
- [ ] No transcript/audio in logs; no secrets in code
- [ ] Doc updated if behaviour differs from spec (and owner informed)


===== FILE: docs/00-preparation.md =====

# 00 — Preparation (owner checklist)

Status: Draft v0.1 · Do these before asking Claude Code to start Phase 0. Items marked (P2) can wait.

## 1. Accounts

| ✓ | Item | Notes |
|---|------|-------|
| ☐ | Google account dedicated to the project | Owns Firebase, Play Console, AI Studio |
| ☐ | Firebase project **`lingomate-dev`** on **Spark** (no billing) | Enable: Firebase AI Logic (Gemini Developer API), App Check, Remote Config, Crashlytics, Analytics |
| ☐ | Gemini API key for dev | Created in the dev project (no billing → free tier). Restrict it: Android app (package + SHA-1 of debug key) and APIs = Generative Language API + Firebase AI Logic API |
| ☐ | GitHub private repo | Branch protection on `main`, Actions enabled |
| ☐ | Google Play Console | $25 one-time. Decide personal vs organization (OQ-8). Personal accounts created after 13 Nov 2023 need a closed test with ≥ 12 testers for 14 continuous days before production |
| ☐ | (P2) Firebase project **`lingomate-prod`** on Blaze | Set budget alerts (e.g. $5, $20, $50) on day one |
| ☐ | (P2) RevenueCat account | Free until $2.5k monthly tracked revenue |
| ☐ | (P2) Firebase Auth providers in `lingomate-prod` | Anonymous, Google, Email link (passwordless). Register SHA-1 + SHA-256 of debug, upload and Play app-signing keys |
| ☐ | (P2) Firebase Hosting | Privacy policy, terms, `/delete-account` request page (required by Play for apps with accounts) |
| ☐ | (P2) Play license testers | Your Google accounts added as license testers to test purchases, renewals, grace period and account hold |

Never link billing to `lingomate-dev`: doing so moves all Gemini usage in that project to paid.

## 2. Tools on the dev machine

- Flutter (stable) + Dart 3; optional `fvm` to pin the version
- Android Studio (latest), Android SDK, **NDK + CMake** (needed by whisper.cpp / sherpa-onnx plugins), JDK 17
- FlutterFire CLI, Firebase CLI (`npm i -g firebase-tools`)
- Node.js LTS (P2, Cloud Functions in TypeScript)
- Claude Code
- `adb`, `scrcpy` (mirror the phone screen while testing), a CSV viewer for benchmark output

## 3. Test devices & gear

| Device | Purpose |
|--------|---------|
| Reference phone: mid-range, 64-bit, 6–8 GB RAM, Android 12+ | All latency/battery ACs are measured here |
| Low-end phone: 64-bit, 3–4 GB RAM, Android 8–10 | Memory/perf floor, ASR model size choice |
| Wired or Bluetooth earphones | Live mode, echo tests |
| Laptop with speakers | Meeting-mode simulation |

32-bit-only devices are not supported (ML Kit).

## 4. Secrets & config

Env files are plain `KEY=VALUE` files (no JSON) in the Flutter project root, one per flavor, passed to Flutter with `--dart-define-from-file` and read with `String.fromEnvironment` (`lib/env.dart`):

| File | Flavor | Committed |
|------|--------|-----------|
| `.env.sample` | Template listing every key, with empty values | Yes |
| `.env.dev` | `dev` | No |
| `.env.staging` | `staging` | No |
| `.env` | `production` | No |

Example `.env.dev`:

```dotenv
GEMINI_API_KEY=AIza...
LIVE_ENABLED=true
APP_CHECK_DEBUG_TOKEN=<token registered in App Check>
```

- `.gitignore` covers `.env`, `.env.dev` and `.env.staging`; add `test_assets/audio/*.wav` if large/private. Firebase client config (`lib/firebase_options_<flavor>.dart`, `android/app/src/<flavor>/google-services.json`) is committed: it is not a secret.
- `GEMINI_API_KEY` goes only in `.env.dev`. Production builds use `.env` and never receive `.env.dev`. CI secret scan fails on `AIza` in release artifacts.

## 5. Audio benchmark set (needed for Phase 0)

Record or collect ~15 clips (30–60 s each, WAV 16 kHz mono), only with voices you have consent to use (your own, friends who agree, or openly licensed audio).

| ID | Scenario | Languages |
|----|----------|-----------|
| C01–C03 | Quiet room, clear speech | vi, en, ja (or your 3rd wave-1 language) |
| C04–C05 | Café noise | vi, en |
| C06–C07 | Played from laptop speaker 50 cm away (meeting sim) | en (accented + native) |
| C08 | Fast speech | en |
| C09 | Vietnamese with English tech terms | vi+en |
| C10–C11 | Two-person conversation, alternating turns | vi↔en |
| C12 | Long monologue without pauses (> 20 s) | en |
| C13 | Numbers, dates, prices, names | vi, en |
| C14 | Glossary terms (P2 tests) | en |
| C15 | Silence + background music | — |

`test_assets/audio/manifest.json`:
```json
[{ "id": "C01", "file": "C01_vi_quiet.wav", "lang": "vi", "scenario": "quiet",
   "reference_transcript": "…", "reference_translation": { "en": "…" } }]
```
Write reference transcripts/translations yourself (or have a fluent friend check them). Free-tier note: anything sent to Gemini on the free tier may be used to improve Google products — don't use confidential recordings.

## 6. Content prep (Phase 1)

- Quick-phrase packs (F-09): 8 situations × ≥ 20 phrases. Workflow: Claude drafts canonical English + slot templates → generate translations for wave-1 languages → you review vi/en; ask fluent friends for ja/ko/zh spot checks → JSON in `assets/quick_phrases/`.
- App name is decided: **Lingo Mate** (D-24); app icon ready in `assets/brand/`. Package id is decided: `com.lingomate.app` (D-25). Before the first Play upload: check the store name/trademark (OQ-7).

## 7. Legal & store prep (by Phase 2)

- Privacy policy page (Firebase Hosting free tier is enough): what is processed (mic audio, transcripts), where (on device; Google Gemini for cloud engines), retention (no audio stored; transcripts on device; optional sync), contact.
- Play **Data safety** answers (see doc 04 §14).
- Consent copy for Listen/Meeting ("Let people know you're translating").
- Ask an accountant about tax on app revenue in Vietnam (OQ-9).
- Not legal advice: recording/processing rules differ by country — confirm for your launch markets.

## 8. Budget guardrails

| Phase | Expected cost | Guardrail |
|-------|---------------|-----------|
| P0–P1 dev | $0 (Spark + free tier) + $25 Play fee | Dev project never billed |
| P2 beta | Gemini usage of testers + Functions (likely within free quota) | Budget alerts; Live off by default; quotas from day one |
| Launch | Per-user AI cost as in doc 09 | Weekly cost review vs. revenue |

## 9. Kick-off with Claude Code

1. Create the repo, copy `CLAUDE.md` to the root together with the `docs/`, `design/` and `assets/` folders (the `assets/` content goes into the Flutter project's `assets/`).
2. Put `.env.dev` (copied from `.env.sample`) in the Flutter project root. Firebase config for the dev flavor is already committed; Claude Code can rerun `./flutterfire-config.sh dev` with you.
3. First prompt (example):

```
Read CLAUDE.md and all files in docs/. Then do Phase 0 task T-0.1 from docs/02-project-plan.md:
bootstrap the Flutter project with dev/prod flavors, Riverpod codegen, go_router, Drift, lints and the
GitHub Actions CI described in docs/03-technical-design.md §15. Stop after T-0.1 and show me what you
created and how to run it. Ask me before deviating from the docs.
```
4. Continue task by task (T-0.2, T-0.3 …), reviewing each PR on a real device.


===== FILE: docs/01-project-spec.md =====

# 01 — Project Spec

Status: Draft v0.1 · Owner: Minh · Last updated: 2026-11-24

## 1. Vision

A pocket interpreter that works **where Google Translate is weak**: without internet, inside meetings, and over time — every conversation becomes material the user can reuse (saved phrases, quick replies, practice).

One-line pitch: *Talk to anyone, in any meeting, even offline — and get better at the language every time you do.*

## 2. Problem statements (working hypotheses)

> The owner's own triggering situation is still an open question (see doc 09, OQ-1). The statements below are hypotheses to validate in beta.

| ID | Problem | Who feels it |
|----|---------|--------------|
| PB-1 | Live translation apps need internet; travellers abroad (roaming, poor signal, regions where Google services are blocked) lose the tool exactly when they need it. | Traveller |
| PB-2 | In online meetings with foreign clients, non-native speakers miss parts of what is said and struggle to answer quickly and correctly. | Professional |
| PB-3 | Translators are throw-away: useful sentences from real conversations are lost; users keep re-translating the same things. | Everyone |
| PB-4 | Phrasebooks are generic; they don't adapt to the user's situations or let them speak a phrase out loud with one tap. | Traveller, Learner |
| PB-5 | Cloud speech AI is expensive; an app that hides cost will either lose money or surprise users. | Owner / business |

## 3. Target users

| Persona | Description | Primary jobs |
|---------|-------------|--------------|
| **Traveller (Linh)** | Vietnamese, travels to JP/KR/TH/CN 2–4×/year, limited English | Order food, ask directions, handle check-in, shop — often offline |
| **Professional (Minh-like)** | Mid-level office/IT worker, joins English meetings with foreign clients | Follow meeting live, catch key terms, answer confidently |
| **Learner (Huy)** | Learning English/Japanese, wants practice from real situations | Save phrases, review, practice speaking |
| **Visitor to Vietnam (Sarah)** | Foreigner living in or visiting Vietnam | Talk to locals in Vietnamese, quick phrases |

Launch market: Vietnam first (vi ↔ en and vi ↔ wave-1 languages), then global (see doc 05, F-24).

## 4. Core use cases

| UC | Use case | Mode |
|----|----------|------|
| UC-1 | Two people facing each other talk in two languages; each reads/hears the other in their language | Conversation (F-02) |
| UC-2 | User listens to a speaker (lecture, tour guide, announcement) and reads captions in their language | Listen (F-03) |
| UC-3 | User joins Zoom/Meet/Teams on a laptop; phone listens through the mic and shows floating captions; user can also see suggested replies | Meeting (F-04, F-19) |
| UC-4 | User saves a useful sentence from any transcript and reviews it later | Phrasebook (F-08), Review (F-16) |
| UC-5 | User opens a situation (restaurant, taxi…) and taps a phrase so the phone speaks it | Quick phrases (F-09) |
| UC-6 | After a conversation, user sees how a native speaker would have phrased what they said | Post-session review (F-17) |

## 5. Goals, non-goals, anti-goals

### Goals
- G-1 Offline translation that is genuinely usable for the wave-1 languages (see doc 05 §F-06).
- G-2 Meeting captions on a phone with end-of-sentence → caption latency ≤ 3 s (p50) in Standard mode.
- G-3 Turn every session into reusable material (save in ≤ 2 taps).
- G-4 Predictable cost: every cloud minute is metered and capped per user (5-hour window + weekly cap).
- G-5 Build the whole product **without a custom backend server**: Firebase/BaaS + Google AI + small Cloud Functions only.

### Non-goals (for now)
- iOS app (later; architecture should not block it).
- Capturing the audio of call apps directly (technically blocked on Android for third-party apps).
- Meeting bots that join Zoom/Meet as a participant (needs an always-on server).
- Human interpreter marketplace, video translation, document/OCR translation (OCR overlay is a separate planned app).
- Web or desktop clients.

### Anti-goals (failure even if it "works")
- AG-1 Audio or transcripts leave the device without the user knowing.
- AG-2 Unbounded cloud spend — any code path that can stream to a paid model without a quota check.
- AG-3 A generic Google Translate clone with nothing personal or offline.
- AG-4 Keeping recordings of other people's voices by default.
- AG-5 Hiding which engine (offline / standard / live) is active, so users can't tell quality or cost.

## 6. Engines and modes (product vocabulary)

| Engine | What runs where | Cost to us | Quality | Needs network |
|--------|-----------------|-----------|---------|---------------|
| **Offline** | On-device ASR + ML Kit translation + on-device TTS | 0 | Basic | No |
| **Standard** | On-device ASR + Gemini Flash-Lite text translation (Firebase AI Logic) + on-device TTS | Very low (~1,100 VND/hour, estimate) | Good, context-aware | Yes |
| **Live** | Gemini Live Translate speech-to-speech over WebSocket | High (~1,100 VND/min) | Best, natural voice, near-simultaneous | Yes |

Modes (UI): Conversation · Listen · Meeting · (later) Media capture. Each mode can use any engine the language pair supports; the app picks the best available and always shows which one is active.

## 7. Scope by phase (summary — details in doc 02 and doc 05)

| Phase | Theme | Key features |
|-------|-------|--------------|
| P0 | Spike & foundations | Benchmark harness, 3 pipelines compared, project skeleton, CI |
| P1 | Core alpha (local-only, no login) | Conversation, Listen, Meeting overlay, engines + auto-select, language packs, transcripts, phrasebook, quick phrases, settings, en/vi UI |
| P2 | Public beta | Sign-in (Google, email link) + Me/Profile + sync + account deletion, Live in production (token function, sign-in required), usage limits, paywall + manage subscription, SRS review, post-session review, glossary, suggested replies, meeting summary |
| P3 | Global & growth | Media capture, roleplay, widget/tile, wave-1 languages everywhere, regional pricing |

## 8. Constraints

| Area | Constraint | Consequence |
|------|-----------|-------------|
| Platform | Android `AudioPlaybackCapture` lets third-party apps capture only `USAGE_MEDIA`, `USAGE_GAME`, `USAGE_UNKNOWN` audio. Call audio (`USAGE_VOICE_COMMUNICATION`) needs a privileged system permission. | Meeting mode = microphone near the laptop speaker. Media capture (YouTube, webinars) is possible later. |
| Platform | ML Kit supports 64-bit ABIs only. | Ship arm64-v8a + x86_64. |
| Backend | No custom server. Only Firebase services, Cloud Functions, third-party APIs. | Server logic limited to small functions (token minting, usage accounting, webhooks). |
| Cost | Live Translate ≈ $0.0368/min (one session); two-session two-way ≈ $0.042/min. | Live is metered, capped and never the silent default for long sessions. |
| Cost (dev) | Dev must cost $0: Firebase Spark plan + Gemini free tier. | Dev flavor uses API key (debug only) and free-tier models; no Cloud Functions in dev. |
| Privacy | Gemini free tier content is used to improve Google products; paid tier is not. | Production must run on the paid tier. Never test with real confidential meeting audio on free tier. |
| Regions | Gemini API is unavailable in some countries (e.g. China, Russia, Iran, Hong Kong, Macau, Myanmar…), checked by caller IP. | Detect "user location not supported" and fall back to Offline with a clear banner. |
| Store | New personal Play Console accounts must run a closed test with ≥ 12 testers for 14 continuous days before production. | Plan recruits testers before P2 ends. |
| Store | Apps that let users create an account must offer account deletion in-app and through a web link. | F-13 includes in-app deletion + `/delete-account` page (D-19). |
| Preview models | Live Translate is a preview model with no stability guarantee. | Standard engine is always available as fallback; model names in Remote Config. |
| Legal | Recording/processing other people's speech is regulated differently by country. | Visible listening indicator, consent notice, no audio storage by default. Not legal advice — owner to confirm. |

## 9. Success metrics (beta targets, to be refined)

| Metric | Target |
|--------|--------|
| Standard mode caption latency (end of utterance → text) | p50 ≤ 2.5 s, p90 ≤ 4 s on reference device |
| Offline mode latency | p50 ≤ 3 s |
| Live mode lag behind speaker | ≤ 3 s typical |
| Translation adequacy (owner/tester rubric 1–5) | ≥ 4.0 Standard, ≥ 3.5 Offline on wave-1 pairs |
| Crash-free sessions | ≥ 99.5% |
| 30-minute meeting soak | No crash, no service kill, latency drift ≤ 1 s |
| Phrases saved per weekly active user | ≥ 3 |
| D7 retention (beta) | ≥ 25% |

## 10. Assumptions

- A-1 Reference device: mid-range Android, 64-bit, 6–8 GB RAM, Android 12+.
- A-2 Users accept downloading 100–500 MB of offline packs for the languages they need.
- A-3 Average paying user consumes ~25% of their quota (drives pricing; validate in beta).
- A-4 Gemini 2.5 Flash-Lite (or successor) remains available at similar price for Standard mode.
- A-5 Pricing is deferred; the quota system must support any limits via Remote Config.

## 11. Glossary

- **Utterance** — one continuous piece of speech by one speaker, bounded by silence (VAD).
- **Session** — one run of a mode from start to stop; contains utterances.
- **Engine** — Offline / Standard / Live translation pipeline.
- **Capability matrix** — per-language table of which engines/features are available.
- **5-hour window** — usage window that starts at first use and resets 5 hours later (Claude-style).
- **Weekly cap** — usage cap that resets 7 days after the week window started.
- **Live block** — minutes reserved when a Live token is issued (≤ 10 min).


===== FILE: docs/02-project-plan.md =====

# 02 — Project Plan

Status: Draft v0.1 · Durations are rough estimates for one developer working with Claude Code; adjust after Phase 0.

## Milestones

| ID | Milestone | Exit criteria | Est. |
|----|-----------|---------------|------|
| M0 | Spike report | OQ-3/4/5 answered with numbers; skeleton + CI green | end of week 2 |
| M1 | Internal alpha | All P1 ACs pass; 30-min Meeting soak passes; ≥ 5 internal testers used it for a week | week 8 |
| M2 | Closed beta start | P2 features behind flags; prod project live; closed test (≥ 12 testers) started | week 12 |
| M3 | Production launch (Vietnam + en) | Closed test 14 days done; P2 ACs pass; crash-free ≥ 99.5%; pricing set (OQ-2) | week 15–16 |
| M4 | Global rollout | F-24 done; regional pricing | after M3 |

## Phase 0 — Spike & foundations (≈ 2 weeks)

Goal: prove the three pipelines and background capture work on real phones, cheaply, before building features.

| Task | Description | Feature | Size | Depends |
|------|-------------|---------|------|---------|
| T-0.1 | Bootstrap repo: flavors dev/prod, Riverpod codegen, go_router, Drift, freezed, lints, folder layout (doc 03 §3), GitHub Actions (analyze, test, release build, secret scan) | — | M | — |
| T-0.2 | Wire Firebase dev: core, App Check (debug), AI Logic, Remote Config defaults, Crashlytics | — | S | T-0.1 |
| T-0.3 | Audio core: 16 kHz PCM capture, Silero VAD, segmenter, 30 s ring buffer, timing instrumentation | — | M | T-0.1 |
| T-0.4 | ASR spike: integrate 2 candidates behind `SpeechRecognizerEngine`; run benchmark (vi, en, +1); pick library + model size → OQ-3 | F-12 | L | T-0.3, T-0.9 |
| T-0.5 | Live spike: dev WebSocket client for `gemini-3.5-live-translate-preview`; one-way; two-session two-way; measure lag/quality; check `gemini-3.8-live` price/support → OQ-4, OQ-5 | F-05 | M | T-0.3 |
| T-0.6 | Standard pipeline spike: ASR → Flash-Lite via AI Logic; latency + adequacy | F-05 | S | T-0.4 |
| T-0.7 | Offline pipeline spike: ASR → ML Kit; latency + adequacy | F-05 | S | T-0.4 |
| T-0.8 | Background spike: foreground service (microphone) + overlay bubble; 30-min soak, screen off, app switching, on reference + low-end phone | F-04 | M | T-0.3 |
| T-0.9 | Benchmark harness + devtools (latency HUD, engine switcher, CSV export) | F-12 | M | T-0.3 |
| T-0.10 | Spike report (`docs/spike-report.md`): tables per pipeline, decisions; update doc 09 + capability matrix `asrOnDevice` ratings | — | S | all |

**Exit (M0)**: report shows whether Standard meets p50 ≤ 2.5 s, Offline p50 ≤ 3 s, Live lag ≤ 3 s; FGS survives 30 min; decisions recorded. If a target is missed, owner decides: adjust target, change library, or re-scope.

## Phase 1 — Core alpha, local-only (≈ 5–6 weeks)

| Task | Description | Feature | Size | Depends |
|------|-------------|---------|------|---------|
| T-1.1 | Design system in code: theme (light/dark), tokens, components, `AppIcon` widget over `assets/icons`, launcher icons per flavor + notification icon (doc 08 §8, `assets/brand/README.md`) | — | M | M0 |
| T-1.2 | Engine layer: interfaces, Offline/Standard/Live(dev) impls, `EngineSelector`, capability matrix, connectivity + region state, engine chip | F-05 | L | T-1.1 |
| T-1.3 | Language packs: ML Kit + ASR model download manager, storage UI | F-06 | M | T-1.2 |
| T-1.4 | Onboarding + permission explainers | F-01 | M | T-1.3 |
| T-1.5 | Conversation mode (tap-to-talk, auto mode, TTS, echo gating) | F-02 | L | T-1.2 |
| T-1.6 | Listen mode | F-03 | M | T-1.2 |
| T-1.7 | Meeting mode: FGS + overlay + in-app transcript | F-04 | L | T-1.2, T-0.8 |
| T-1.8 | Sessions & transcripts (Drift, FTS search, share) | F-07 | M | T-1.5 |
| T-1.9 | Phrasebook (save flows from all modes, tags, search) | F-08 | M | T-1.8 |
| T-1.10 | Quick phrases: content JSON (8 situations) + UI + show mode | F-09 | M | T-1.1 |
| T-1.11 | Settings & privacy (delete all data, consent toggles, licenses) | F-10 | S | T-1.2 |
| T-1.12 | Localization: English source ARB + vi, App language setting (in-app + Android 13 per-app), wave-1 partner-facing strings, golden tests at 1.0/2.0 text scale | F-11 | S | ongoing |
| T-1.13 | Internal testing track release, bug bash, fix | — | M | all |

**Exit (M1)**: all P1 ACs pass on reference device; no P0/P1 bugs open; internal testers' feedback triaged. Owner answers OQ-1 (core pain point) before T-1.5 so the hero mode gets polish first.

## Phase 2 — Public beta (≈ 5–6 weeks)

| Task | Description | Feature | Size | Depends |
|------|-------------|---------|------|---------|
| T-2.1 | Prod Firebase project (Blaze) + budget alerts + App Check Play Integrity + Remote Config prod values | — | S | M1 |
| T-2.2 | Account: anonymous auth, sign-in screen S-24 (Google via Credential Manager, email link), linking/merge, Me/Profile S-17 + account details, sign-out, Firestore profile + rules + sync | F-13 | L | T-2.1 |
| T-2.3 | Cloud Functions: `issueLiveToken`, `reportLiveUsage`, `cleanupLiveTokens` + emulator tests | F-14 | M | T-2.2 |
| T-2.4 | Live in prod via ephemeral tokens; session rotation; fallback | F-05 | M | T-2.3 |
| T-2.5 | Usage limits + usage sheet + warnings | F-14 | M | T-2.3 |
| T-2.6 | RevenueCat, paywall S-19, top-ups, webhook → plan + transactions, Manage subscription S-25 (states incl. billing issue), purchase history (pricing from OQ-2) | F-15 | L | T-2.2 |
| T-2.7 | SRS review + reminders | F-16 | M | T-1.9 |
| T-2.8 | Post-session review, glossary, suggested replies, summaries | F-17–F-20 | L | T-1.8 |
| T-2.9 | Privacy policy, Data safety, store listing (en, vi), screenshots | — | S | — |
| T-2.10 | Closed test: recruit ≥ 15 testers (buffer over 12), keep them opted in 14 continuous days | — | — | start at M2 |
| T-2.11 | Production access application + release | — | S | T-2.10 |
| T-2.12 | Account deletion: in-app flow, `deleteAccount` function, `/delete-account` web page, Data safety deletion answers | F-13 | M | T-2.2 |

**Exit (M3)**: P2 ACs pass; closed test complete; account deletion works in-app and on the web; measured average usage vs. A-3 (25% of caps) reviewed and pricing finalized.

Note: sign-in/profile stay in P2 unless the owner moves them into P1 (OQ-12).

## Phase 3 — Global & growth (ongoing)

| Task | Description | Feature |
|------|-------------|---------|
| T-3.1 | Wave-1 UI languages + localized store listings | F-24 |
| T-3.2 | Regional price groups | F-24 |
| T-3.3 | Media capture mode | F-21 |
| T-3.4 | Roleplay practice | F-22 |
| T-3.5 | Widget + Quick Settings tile | F-23 |
| T-3.6 | Revisit blocked-region coverage (OQ-11) and iOS feasibility | — |

## Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|-----------|
| R-1 | Live Translate (preview) changes behaviour/price or is withdrawn | Med | High | Model name in Remote Config; Standard fallback always available |
| R-2 | On-device Vietnamese ASR too slow/inaccurate on mid-range phones | Med | High | Spike T-0.4 with 2 libraries; allow Standard with cloud ASR as later option |
| R-3 | OEM battery managers kill the foreground service | Med | Med | Soak tests on multiple brands; in-app guide; detect and notify |
| R-4 | Echo loop (app translates its own TTS) | High | Med | Half-duplex gating; AEC experiment; headphone hint |
| R-5 | Cloud cost overrun | Med | High | Server-enforced Live quota; budget alerts; max-usage-safe pricing (doc 09) |
| R-6 | Can't keep 12 testers for 14 days | Med | Med | Recruit 15–20; start closed test early; consider organization account |
| R-7 | Users in Gemini-blocked regions | Low (VN launch) | Med | Offline mode + clear banner |
| R-8 | Flash-Lite model retired/price rise | Med | Med | Remote Config model name; re-run cost model |
| R-9 | Consent/recording law issues | Low | High | Indicator, consent sheet, no audio storage; owner checks laws per market |

## How to brief Claude Code per task

```
Task: T-1.5 Conversation mode (F-02).
Read: docs/05 (F-02), docs/06 (AC-02.x), docs/03 §5–7, docs/08 (S-05), Figma frame S-05 (link in design/README.md; read with the Figma MCP server).
Deliver: feature folder + tests covering every AC that can be automated; list ACs needing manual device checks.
Constraints: follow CLAUDE.md hard rules; no new dependencies without asking.
```


===== FILE: docs/03-technical-design.md =====

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
├─ .env.sample                # committed; every key, empty values (KEY=VALUE)
├─ .env.dev                   # gitignored; GEMINI_API_KEY (dev only), flags
├─ .env.staging               # gitignored
├─ .env                       # gitignored; production
├─ lib/
│  ├─ main_dev.dart
│  ├─ main_staging.dart
│  ├─ main.dart               # production
│  ├─ firebase_options_dev.dart  # generated by flutterfire-config.sh
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
- **Credentials**: dev = API key from `.env.dev` (dev flavor only); prod = ephemeral token from `issueLiveToken` (single use, short expiry ≤ quota block). Token expiry ends the session; client requests a new token (quota checked again).
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

| Flavor | Package id | Env file | Firebase project | Plan | Live credentials | Devtools |
|--------|------------|----------|------------------|------|------------------|----------|
| `dev` | `com.lingomate.app.dev` | `.env.dev` | `lingo-mate-dev` (id `lingo-mate-4f38d`) | Spark ($0) | API key via `--dart-define-from-file=.env.dev` | Enabled |
| `staging` | `com.lingomate.app.staging` | `.env.staging` | Not connected yet | — | — | Enabled |
| `production` | `com.lingomate.app` | `.env` | `lingomate-prod` (not created yet, P2) | Blaze (from P2) | Ephemeral token from `issueLiveToken` | Disabled |

CI (GitHub Actions): `flutter analyze`, `flutter test`, build `production` release APK, **secret scan** (fail if `AIza` or `.env.dev` content appears in the release artifact), functions lint/test (P2).

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


===== FILE: docs/04-integrations.md =====

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

- Two Firebase projects: `lingo-mate-dev` (project id `lingo-mate-4f38d`, Spark, never linked to billing) and `lingomate-prod` (Blaze from P2, not created yet).
- Configure with FlutterFire CLI per flavor via `./flutterfire-config.sh dev|staging|prod` → `lib/firebase_options_<flavor>.dart` and `android/app/src/<flavor>/google-services.json`. Only `dev` is connected today (Android app `com.lingomate.app.dev`).
- `main_dev.dart` calls `Firebase.initializeApp` with `firebase_options_dev.dart`; `main.dart` (production) and `main_staging.dart` do the same once their projects exist.
- Env values come from `.env.dev` / `.env.staging` / `.env` (`KEY=VALUE`, no JSON) via `--dart-define-from-file`.

**Why separate projects**: linking a billing account switches all Gemini Developer API usage in that project to pay-as-you-go. Keeping dev on Spark keeps dev free.

## 2. Firebase App Check

- Required: Firebase AI Logic is deactivated for projects without App Check enforcement (requirement effective 2 Nov 2026).
- Dev: debug provider with a fixed token: `AndroidDebugProvider(debugToken: …)` reads `APP_CHECK_DEBUG_TOKEN` from `.env.dev`. Token `local-dev` is registered for the dev app (App Check → Apps → Manage debug tokens); its value lives only in the owner's `.env.dev`. A token printed in logcat also works once registered there.
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

- **Dev auth**: `?key=<GEMINI_API_KEY>` from `.env.dev` (dev flavor only).
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


===== FILE: docs/05-feature-specs.md =====

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


===== FILE: docs/06-feature-details-acs.md =====

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
| AC-03.4 | Given a monologue longer than 15 s without pause, Then it is cut at the nearest pause > 250 ms (or hard cut at 15 s) and captions keep flowing. |
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


===== FILE: docs/07-test-plan.md =====

# 07 — Test Plan & Test Strategy

Status: Draft v0.1

## 1. Objectives

1. Prove each pipeline meets latency/quality targets on real phones (doc 01 §9).
2. Guarantee no cost leak: every paid call is metered and capped.
3. Guarantee privacy promises: no audio persisted, no transcripts in logs, no keys in release.
4. Keep regressions out with a fast automated suite; reserve manual time for audio/device behaviour that can't be automated.

## 2. Test levels

| Level | Tools | Scope | Target |
|-------|-------|-------|--------|
| Unit | `flutter_test`, `mocktail`, fake clock (`clock` package) | Domain + application: selector, quota math, VAD segmentation logic, SRS, prompt builders, capability parsing, slot templates, sync merge | ≥ 80% line coverage in `domain/` + `application/` |
| Widget | `flutter_test` | Every screen in loading / empty / content / error states; engine chip states | All P1 screens |
| Golden | `alchemist` or `golden_toolkit` | Key screens × light/dark × en/vi × text scale 1.0/2.0 | S-04, S-05, S-06, S-08, S-11, S-14, S-16, S-17, S-18, S-19, S-24, S-25 |
| Integration | `integration_test` with fake engines | Navigation flows, session lifecycle, save-to-phrasebook, fallback switching | Happy paths per feature |
| Backend | Firebase Emulator Suite + Jest/Vitest | Firestore rules, Functions (`issueLiveToken`, `reportLiveUsage`, webhook) | 100% of rules paths; quota edge cases |
| Platform | Android instrumentation (Kotlin) | Foreground service lifecycle, overlay, PcmPlayer | Start/stop/kill paths |
| Benchmark | Devtools benchmark runner (F-12) | Latency + accuracy per pipeline on the audio set | Every pipeline change + weekly in P1 |
| Manual device | Test matrix §7 | Real audio, noise, interruptions, OEM behaviour | Each release candidate |
| Beta | Play internal → closed tracks | Real-world usage, crash/ANR, feedback | ≥ 12 testers × 14 days |

## 3. Critical units to cover first

- `EngineSelector`: every branch of doc 03 §7 (online/offline, region block, quota, packs, capability, user pin, error burst).
- `QuotaWindow` math: start on first use, reset at +5 h / +7 d, boundary at exactly reset time, multiple engines, top-up consumption order (allowance → top-up), clock changes/time zones.
- `Segmenter`: silence threshold, min speech, max 15 s cut at nearest pause > 250 ms.
- `EchoGate`: no segments emitted during TTS speaking + 150 ms tail.
- `TranslatorPrompt`: context window (last 3), glossary injection, escaping.
- `CapabilityMatrix` parsing: malformed JSON → defaults + non-fatal report.
- `Sm2Scheduler` against reference table.
- Phrase dedupe rule; sync last-write-wins with soft deletes.
- Live client: setup message shape, 100 ms framing, goAway → resume, token expiry → re-request.
- `SubscriptionStateMapper`: CustomerInfo fixtures → free / active / cancelled / billingIssue / expired (doc 03 §17.4).
- `AuthGate.requireSignIn`: anonymous → opens sign-in and resumes the original action; signed-in → runs immediately.
- Account merge: local phrases merged into an existing account without duplicates; `owner_uid` reassignment on sign-out Keep/Remove.

## 4. Fakes & test doubles

`FakeAsrEngine`, `FakeTextTranslator(latency, failures)`, `FakeTts(speakDuration)`, `FakeLiveSession(script)`, `FakeConnectivity`, `FakeRemoteConfig`, `FakeClock`. All engines are injected via Riverpod overrides, so widget/integration tests never hit the network or models.

## 5. Spike & benchmark protocol (Phase 0 and ongoing)

**Inputs**: `test_assets/audio/manifest.json` (doc 00 §5). Clips are fed as if from the mic (real-time pacing) to keep latency realistic; one run also via the phone speaker → mic for Meeting realism.

**Timestamps per utterance**
- `t0` VAD speech end · `t1` ASR final text · `t2` translation text rendered · `t3` TTS/audio playback start
- Standard/Offline latency = `t2 − t0`; spoken latency = `t3 − t0`.
- Live lag = time from end of a source sentence (from clip annotations) to the first translated audio chunk of that sentence; also record the "ear-voice span" while speech continues.

**Quality**
- ASR: WER (vi, en, es, fr, de, id) / CER (ja, ko, zh, th) vs reference transcript.
- Translation adequacy rubric (owner or fluent tester), per utterance:
  - 5 meaning fully preserved, natural · 4 preserved, minor awkwardness · 3 main meaning, some loss · 2 significant errors · 1 wrong/unintelligible
- Side detection accuracy (Conversation auto mode) on C10–C11.

**Resources**: peak RAM, CPU %, battery % per 10 min, device temperature (start/end), model size.

**Pass criteria (reference device)**

| Pipeline | Latency | Quality |
|----------|---------|---------|
| Standard | p50 ≤ 2.5 s, p90 ≤ 4 s | adequacy ≥ 4.0 avg (wave-1 pairs tested) |
| Offline | p50 ≤ 3 s | adequacy ≥ 3.5 avg |
| Live | lag ≤ 3 s typical | adequacy ≥ 4.0; two-way: correct direction ≥ 95% of sentences |
| ASR (chosen) | ≤ 1.5 s for a 5 s segment | WER vi ≤ 20%, en ≤ 12% on quiet clips (tune after first run) |

**Output**: CSV from F-12 + `docs/spike-report.md` with tables and a recommendation per OQ.

## 6. Backend tests (Phase 2)

- Rules: user reads own docs only; client cannot write `usage/live`, `liveTokens`, `plan`; `usage/standard` increments ≤ 600 s per write and window starts only move forward.
- `issueLiveToken`: unauthenticated → denied; missing App Check → denied; remaining < 60 s → `allowed:false` + `resetAt`; reservation atomic under 10 concurrent calls; block = min(600, remaining); two tokens for two-way share one reservation.
- `reportLiveUsage`: refund once; `usedSec > blockSec` clamps to 0 refund; unknown token ignored.
- Webhook: signature/secret check; plan transitions (purchase, renewal, cancel, billing issue, expiry, refund); `planState` correct for each; top-up adds seconds idempotently (event id); `transactions/{eventId}` written once.
- `issueLiveToken` with an anonymous token → `sign_in_required`, no token, no reservation.
- `deleteAccount`: requires recent login; removes `users/{uid}` subtree, live tokens, RevenueCat customer call made, Auth user deleted; second call is a no-op; rules deny all reads for the deleted uid afterwards.
- Profile rules: owner can write `displayName`, `myLanguages`, `uiLocale`, `stats`; cannot write `plan*` or `liveTopupSec`.

## 7. Manual device test matrix

| ID | Scenario | Expected |
|----|----------|----------|
| M-01 | Conversation, quiet room, tap-to-talk vi↔en | AC-02.2/02.3 met |
| M-02 | Conversation in café noise | Usable captions; no crash |
| M-03 | Airplane mode toggled mid-session | Switch to Offline (packs) or pause banner |
| M-04 | Wi-Fi → mobile data handover | Session continues; ≤ 1 utterance lost |
| M-05 | Meeting 30 min, screen off, switching apps | No kill; AC-04.6/04.9 |
| M-06 | Incoming phone call during session | Capture pauses, resumes after call; no translation of the call |
| M-07 | Bluetooth headset connect/disconnect | Audio route switches; capture continues |
| M-08 | Low storage during pack download | Clear error; no corrupt "Ready" state |
| M-09 | Revoke mic permission while running | Session stops gracefully with explanation |
| M-10 | Process killed by system / OEM | Notification removed; next open shows session saved up to last utterance |
| M-11 | TTS speaking near mic (speaker on) | No self-translation loop (AC-02.4) |
| M-12 | Dark mode, 200% text, TalkBack | All controls reachable and labelled |
| M-13 | Region block simulated (devtools forces error) | Banner; Offline only (AC-05.5) |
| M-14 | (P2) Live session > 10 min | Seamless token/session rotation; usage charged per block |
| M-15 | (P2) Quota exhausted mid-session | Switch at utterance boundary; usage sheet |
| M-16 | (P2) Purchase, restore, cancel with license testers | Entitlements correct |
| M-17 | Low-end phone full flow | No ANR; memory within limits |
| M-18 | (P2) Continue with Google as anonymous user with local phrases | Same uid, phrases kept (AC-13.3) |
| M-19 | (P2) Email link opened on same device / on another device / after expiry | Signs in / asks for email / clear error + resend (AC-13.5) |
| M-20 | (P2) Sign in on a 2nd phone with an existing account, choose Merge | Local phrases merged without duplicates (AC-13.4) |
| M-21 | (P2) Subscription states with license testers: purchase, accelerated renewal, cancel, declining test card → grace period, account hold, recover | S-25, Me plan card and quotas match each state (AC-15.6–15.9) |
| M-22 | (P2) Delete account in app (with and without active subscription) and via web page | Data gone, onboarding shown, Play warning when subscribed (AC-13.12–13.14) |

Run on: reference phone + low-end phone each release candidate; plus at least 2 other OEM brands during closed beta.

## 8. Performance & soak

- Cold start ≤ 2 s (profile mode, reference device).
- 30-minute Meeting soak (Standard) and 15-minute Live soak: no crash/ANR, memory growth < 50 MB, latency drift ≤ 1 s.
- Battery: ≤ 8% per 30 min Meeting (Standard), measured from 100% → after session with screen off.
- Jank: < 1% frames over 16 ms on caption list scrolling (DevTools).

## 9. Security & privacy tests

- Release APK: `strings`/apktool scan finds no `AIza` key and no `.env.dev` content (automated in CI).
- File-system check after sessions: no audio files in app dirs (AC-07.6).
- Logcat in release: no transcript text (automated grep during integration run).
- Offline mode network check: with packs installed and Standard disabled, proxy shows no requests to Gemini endpoints during a session.
- App Check: requests without valid token rejected (prod).
- Delete all data: DB, prefs, models (optional), cloud docs removed.

## 10. Localization & accessibility

- Pseudo-locale run for overflow; en/vi goldens at text scale 1.0 and 2.0.
- Locale resolution unit tests: device vi → vi; device fr → en; explicit choice beats device; "Phone language" resets; signed-in `uiLocale` applied on a fresh device (AC-11.3–11.7).
- Manual on Android 13+: system Settings → App languages and the in-app setting stay in sync (AC-11.6).
- TalkBack walkthrough of P1 flows; minimum touch target 48 dp; contrast AA (doc 08).

## 11. Cost verification

- Unit tests for quota math with fake clock (§3).
- Beta weekly reconciliation: sum of `usage_ledger` + function reservations vs. Gemini billing for the prod project; investigate > 10% gap.
- Alerting: budget alerts at 50/90/100% of monthly budget.

## 12. Bug severity

| Sev | Definition | Release blocker |
|-----|------------|-----------------|
| S1 | Crash/ANR in core flow, data loss, privacy/security breach, unmetered paid usage | Yes |
| S2 | Core feature broken with workaround, wrong translation direction, engine chip wrong | Yes for production |
| S3 | Minor functional/UX issue | No |
| S4 | Cosmetic | No |

## 13. Entry / exit criteria

| Phase | Entry | Exit |
|-------|-------|------|
| P0 | Prep checklist (doc 00) done | Spike report; benchmark CSVs; decisions in doc 09 |
| P1 | M0 | All P1 ACs; unit/widget/golden green; manual matrix M-01…M-13 pass; no S1/S2 open |
| P2 | M1 | All P2 ACs; backend tests green; closed test 14 days; crash-free ≥ 99.5%; cost reconciliation within 10% |

## 14. Release checklist

- [ ] Version/build bumped; changelog
- [ ] `flutter analyze` clean; all tests green; goldens updated intentionally
- [ ] Secret scan passed; prod flavor; Remote Config prod values reviewed (`ff_*`, models, quotas)
- [ ] Manual matrix on 2 devices
- [ ] Crashlytics symbols uploaded
- [ ] Data safety + privacy policy match current behaviour
- [ ] Staged rollout (10% → 50% → 100%) with crash/ANR watch


===== FILE: docs/08-design-system.md =====

# 08 — Design System & Screen Specs

Status: Draft v0.1 · Visual design lives in **Figma** (D-23): https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k — page "Lingo Mate UI v0.1", English UI copy (D-22); per-screen frame links in `design/README.md`. (The earlier claude.ai canvas https://claude.ai/artifact/D6ThFTUmcSi5zo57nnMSX2 is an archive and is no longer updated.) 17 screen frames using the same tokens and screen IDs (S-01, S-04–S-08, S-10, S-11, S-13–S-19, S-24, S-25), plus an App icon sheet and the in-app icon set (§8). Static exports for offline use and Claude Code: `design/screens/` (PNG per screen), `design/html/` (HTML source), `design/LingoMate-UI-Design.pdf` — see `design/README.md`. This document is the source of truth if they differ. Some mockups already show P2 elements (Suggest reply / Summarize buttons, summary card, "how a native would say it", review banner, usage sheet, paywall, sign-in, account & plan cards on Me, manage subscription) — build those only in Phase 2. Prices on the paywall are placeholders (OQ-2). Implement tokens in `lib/app/theme/`.

## 1. Design direction — "Two sides of the table"

- **Legibility first**: captions are read at arm's length, often by a stranger. Big type, high contrast, generous line height, full Vietnamese diacritic and CJK/Thai support.
- **Two parties, two surfaces**: the user's side is light ("paper"), the partner's side is dark ("ink"). This split appears in Conversation and in show mode, so who-reads-what is obvious.
- **Honest engine state**: one chip, always visible, colour-coded: Offline (graphite), Standard (lagoon), Live (on-air coral with a pulsing dot).
- **Calm, warm, not techy**: warm paper background, rounded shapes, one brand colour, no gradients behind text.

## 2. Tokens

### 2.1 Colour (light / dark)

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `paper` | #FAF8F4 | #0F1117 | App background |
| `surface` | #FFFFFF | #181B24 | Cards, sheets |
| `surfaceAlt` | #F1EDE4 | #222634 | Secondary cards, inputs |
| `ink` | #14161F | #F4F2EC | Primary text |
| `inkMuted` | #5B6070 | #A7ABB8 | Secondary text, originals under translations |
| `line` | #E4DFD3 | #2C3141 | Dividers, borders |
| `brand` (Lagoon) | #0F766E | #2DD4BF | Primary actions, Standard engine |
| `brandSoft` | #CCF2EC | #123B38 | Brand tint backgrounds |
| `onBrand` | #FFFFFF | #04201D | Text on brand |
| `partnerBg` | #14161F | #F4F2EC | Partner half (inverted) |
| `onPartner` | #F4F2EC | #14161F | Text on partner half |
| `engineOffline` | #475569 / bg #E2E8F0 | #CBD5E1 / bg #273142 | Offline chip |
| `engineStandard` | #0F766E / bg #CCF2EC | #2DD4BF / bg #123B38 | Standard chip |
| `engineLive` | text #B4232A / bg #FFE4E5 / dot #E5484D | text #FF7A7E / bg #3D1A1C / dot #FF7A7E | Live chip, on-air dot |
| `success` | #15803D | #4ADE80 | Ready, saved |
| `warning` | #B45309 | #FBBF24 | Usage 80%, missing voice |
| `danger` | #B91C1C | #F87171 | Errors, delete |
| `listening` | #0F766E | #2DD4BF | Mic ring pulse |

All text/background pairs must meet WCAG AA (4.5:1 body, 3:1 large text ≥ 24 px).

### 2.2 Typography

- UI & captions: **Be Vietnam Pro** (Google Fonts, OFL) — designed for Vietnamese diacritics. Weights 400/500/600/700.
- Fallbacks per script: Noto Sans JP / KR / SC / TC / Thai (bundle only the scripts of downloaded languages, or rely on system Noto).
- Numbers in usage meters: tabular figures.

| Style | Size / line height | Weight | Use |
|-------|--------------------|--------|-----|
| `display` | 40 / 48 | 700 | Show mode translation |
| `captionXL` | 28 / 38 | 600 | Live translation (Conversation, Listen) |
| `captionL` | 22 / 30 | 500 | Previous translations, overlay |
| `title` | 22 / 28 | 700 | Screen titles |
| `headline` | 18 / 24 | 600 | Card titles |
| `body` | 16 / 24 | 400 | Body |
| `original` | 15 / 22 | 400, `inkMuted` | Source text under translations |
| `label` | 14 / 20 | 600 | Buttons, chips |
| `small` | 12 / 16 | 500 | Metadata, timestamps |

Caption size is user-adjustable (0.8×–1.6×).

### 2.3 Spacing, radius, elevation, motion

- Spacing scale (dp): 4, 8, 12, 16, 20, 24, 32, 48. Screen padding 20. Card padding 16.
- Radius: chip 999, button 16, card 20, sheet 28, mic button circle.
- Elevation: flat cards with 1 px `line` border; sheets and overlay bubble use shadow `0 8 24 rgba(20,22,31,0.18)`.
- Motion: 200 ms standard ease; mic listening ring pulses 1.2 s loop; Live dot pulses 1.0 s; respect "reduce motion".
- Touch targets ≥ 48 dp; mic button 88 dp (Conversation), 72 dp elsewhere.

## 3. Components

| Component | States / variants | Notes |
|-----------|-------------------|-------|
| `MicButton` | idle · listening (pulsing ring) · processing (spinner arc) · disabled · speaking (TTS, muted mic icon) | Center icon + label under ("Tap to speak" / "Listening…") |
| `EngineChip` | offline · standard · live (pulsing dot) · unavailable | Tap → engine sheet with reasons |
| `LanguagePairPill` | `VI ⇄ EN`, swap button, tap language to change | Shows flag-free language codes + names (no flags: languages ≠ countries) |
| `CaptionItem` | live (being spoken) · final · saved (bookmark filled) · fallback badge | Translation on top (captionL/XL), original below (original style) |
| `CaptionList` | auto-scroll · paused with "Jump to live" FAB | |
| `OverlayBubble` | collapsed (2–3 lines) · expanded (~8 lines) · paused | Rounded 20, drag handle, engine dot, stop button |
| `ModeCard` | primary (Conversation) · secondary (Listen, Meeting) | Icon, title, one-line description |
| `SituationTile` | default · favorite | Icon + name + phrase count |
| `PhraseRow` | default · playing · favorite | Translation, original, play button |
| `PackRow` | not downloaded · downloading % · ready · update · not available offline | Size + action |
| `UsageBar` (P2) | normal · warning (≥ 80%) · exhausted | Label + reset time |
| `PlanCard` (P2) | default · highlighted · current | Price from store |
| `Banner` | info · warning · error | Icon, text, optional action |
| `Toast` | info · success | Bottom, 3 s, optional Undo |
| `ShowModeView` | normal · rotated 180° | Full-screen partner text |
| `ExplainerSheet` | permission · consent · placement | Illustration, title, body, primary/secondary actions |
| `SignInButton` (P2) | Google · email · disabled · loading | Google button must use Google's official "Sign in with Google" branding assets (the mockup shows a placeholder where the mark goes) |
| `AccountCard` (P2) | signed in · anonymous ("Sign in to sync and use Live") | Avatar (photo or initials), name, email · provider |
| `PlanStatusCard` (P2) | free · active · cancels on date · payment issue · expired | Ink surface; status line coloured (amber for payment issue); usage mini-bars; "Manage plan" |
| `StatTile` | — | Big number + label (hours translated, phrases saved, streak) |
| `SettingsRow` | navigation · value · destructive | Label, optional value, chevron; ≥ 48 dp |
| `BillingIssueBanner` (P2) | — | Amber (#FEF3C7 bg / #78350F text), warning icon, date, action |

## 4. Navigation

Bottom navigation (4 tabs): **Translate** (S-04) · **Phrases** (S-13 quick / S-11 mine) · **History** (S-09) · **Me** (S-17 profile: account, plan, stats, settings).

```
Onboarding S-01 → S-02 → (S-16 packs offer) → S-04
S-04 Translate ─┬─ Conversation S-05 ─ engine sheet / bubble actions / show mode S-15
                ├─ Listen S-06
                └─ Meeting S-07 ─ overlay S-08 (system window)
Phrases ─┬─ Quick S-13 → Situation S-14 → Show mode S-15
         └─ Mine S-11 → Phrase detail S-12   (P2: Review S-20 banner)
History S-09 → Transcript S-10 (P2: summary, post-session review S-21)
Me S-17 → Language packs S-16 · (P2) Sign in S-24 · Usage S-18 · Manage subscription S-25 → Paywall S-19 · Glossary S-22 · (dev) Devtools S-23
Sign in S-24 is also opened from: Live start (anonymous), sync toggle, purchase/restore, Paywall
```

## 5. Screen specs

Wireframes are schematic; for visuals see `design/screens/<S-id>-*.png` (exact values in `design/html/`).

### S-01 Welcome
```
[ illustration: two speech bubbles, one light one dark ]
Talk to anyone.
Even offline. Even in meetings.
• Live captions & voice   • Works without internet   • Learn from every chat
🔒 Your audio is never saved.
[ Get started ]
```
Top-right: App language selector (`English ▾`, globe icon) so people who don't read English can switch before onboarding (F-11).

### S-02 Language setup
Step 1 "I speak" (single select, search), Step 2 "I talk with" (multi-select chips; badges "Offline", "Live"; wave-1 on top). Progress dots. [Continue].

### S-03 Permission explainer (shown just-in-time)
Icon, "Lingo Mate needs the microphone to hear the conversation. Audio is processed and then discarded — nothing is recorded." [Allow microphone] [Not now].

### S-04 Translate (Home)
```
┌ [VI ⇄ EN]                    (● Standard) ┐
│ ┌──────────────────────────────────────┐ │
│ │  🎙  Conversation                      │ │  primary card, brand
│ │  Talk face to face                     │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────────┐ ┌──────────────┐        │
│ │ 👂 Listen    │ │ 💻 Meeting   │        │
│ └──────────────┘ └──────────────┘        │
│ Quick phrases  ★ Thank you · Bill please →│
│ Offline ready: VI ✓ EN ✓ JA ↓            │
│ Continue: "Lunch with Kenji" · 12 min     │
└ [Translate] [Phrases] [History] [Me]      ┘
```

### S-05 Conversation
```
┌────────── partner half (ink bg, rotated 180°) ─────────┐
│  "Tôi muốn đặt bàn cho hai người" (original, small)     │
│  I'd like a table for two.            (captionXL)       │
│                 ( 🎙 88dp )  English                     │
├──────────── divider: [● Standard ▾]  [⇅ auto] ─────────┤
│  Sure, how many people?  → "Vâng, mấy người ạ?"         │
│  Vâng, mấy người ạ?                    (captionXL)      │
│                 ( 🎙 88dp )  Tiếng Việt                  │
│  [🔊 Speak on]  [⋯]                       paper bg      │
└─────────────────────────────────────────────────────────┘
```
States: idle, listening (ring), processing, speaking (TTS), offline fallback toast, paused banner.
The partner half's chrome (language label, "Tap to speak" hint) is in the partner's language, using the bundled partner-facing strings (F-11); fallback English.

### S-06 Listen
Header: source `JA ▾ → VI`, engine chip, font size, keep-screen-on. Caption list (translation big, original small, timestamps). Bottom bar: big Pause/Resume, Stop. "Jump to live" FAB when scrolled.

### S-07 Meeting (in app)
Setup card first time (placement illustration: phone next to laptop speaker; consent note). Running state: transcript list with speaker-turn separators, overlay toggle, engine chip, Live toggle (if allowed), Stop. P2: "Suggest reply", "Summarize".

### S-08 Caption overlay (system window)
```
╭──────────────────────────────╮
│ ● Standard          ⤢   ■    │
│ …so we can ship by Friday.    │
│ Chúng ta có thể giao vào thứ  │
│ Sáu.                          │
╰──────────────────────────────╯
```
Collapsed 2–3 lines, expanded ~8, draggable, semi-opaque surface (95%), long-press line → save.

### S-09 History
Search bar; grouped by Today / Yesterday / date; row: mode icon, title, `VI⇄EN`, duration, engine dots, first line.

### S-10 Transcript
Header: title (editable), date, duration, engines used; actions Share, Delete. Utterance list with side colors (me = paper, partner = surfaceAlt), engine badge when fallback. P2: Summary card at top; "How would a native say it?" button (F-17).

### S-11 My phrasebook
Segmented `Quick | Mine` at top of Phrases tab. Search, filter chips (pair, tags, ★). Rows: translation (headline), original (original style), play. FAB "+ Add phrase". P2 banner: "12 cards to review".

### S-12 Phrase detail
Both sides large with play buttons, note, tags editor, "From: Lunch with Kenji · 12:41", Show large, Delete.

### S-13 Quick phrases (situations)
Favorites row; grid of situation tiles (Airport, Hotel, Restaurant, Taxi & directions, Shopping, Health & emergency, Small talk, Meeting basics). Target language selector.

### S-14 Situation detail
Phrase rows (user language + translation); slot chips inline ("for [2] people at [7 pm]"); tap = speak; long-press = show mode; star.

### S-15 Show mode
Full screen partner surface (ink), translation in `display`, original small, buttons: rotate 180°, speak, close.

### S-16 Language packs
Storage summary bar; Wi-Fi only switch; list of PackRows grouped: "Your languages", "All languages".

### S-17 Me / Profile
```
Me
┌ (AM)  Alex Morgan                        › ┐   AccountCard → account details
│       alex@example.com · Google            │   (anonymous: "Sign in to sync and use Live")
└────────────────────────────────────────────┘
┌ Pro · monthly            [ Manage plan ]  ┐   PlanStatusCard (ink)
│ ● Payment needs updating                   │   status line
│ Live this month 18/30 min │ Standard 3.2/10 h│  → Usage S-18
└────────────────────────────────────────────┘
[ 12 h translated ] [ 86 phrases ] [ 5-day streak ]
My languages                 EN, VI, JA   ›
App language                    English   ›   Phone language (default) / English / Tiếng Việt
Offline packs                     640 MB   ›   → S-16
Translation & voice                 Auto   ›
Privacy & data                 Sync: on   ›   analytics, crash reports, delete data, delete account
Help & feedback                            ›
Sign out                                       (destructive colour)
[Translate] [Phrases] [History] [Me]
```
P1 (no login): account and plan cards hidden; settings list only.

Account details (pushed from AccountCard): photo/initials, display name (editable), email, provider, linked since; Sign out; **Delete account** (red, bottom).

### S-18 Usage (P2, bottom sheet)
```
Standard   ███████░░░  this 5-h window 21/30 min · resets 14:30
           ███░░░░░░░  this week 2.1/6 h · resets Mon 09:12
Live       ██░░░░░░░░  this month 6/30 min · top-up 0 min
[ Get more Live minutes ]   [ See plans ]
```

### S-19 Paywall (P2)
Monthly/Yearly toggle; plan cards (Free, Pro Lite, Pro highlighted) with feature checklist and store prices; Live top-up packs; Restore purchases; terms/privacy links.

### S-20 Review (P2)
Card front (prompt), tap to reveal, Again/Hard/Good/Easy buttons, progress, streak.

### S-21 Post-session review (P2)
List of items: "You said" (original) → "A native speaker would say" (improved) + one-line reason + Save.

### S-22 Glossary (P2)
Sets list → terms table (term, translation, note), add/edit, "Use in sessions" toggle.

### S-24 Sign in (P2)
```
                                         ✕
[ small two-bubble motif ]
Sign in to keep everything with you
✓ Sync phrasebook and review schedule across devices
✓ Use Live minutes and keep Pro when you switch phones
✓ Restore your data after reinstalling
[ (G) Continue with Google ]      official Google branding
[ ✉  Continue with email   ]
  Later — use without an account   (text button)
▯ Offline translation always works without signing in.
By continuing you agree to the Terms and Privacy Policy.
```
The reason line under the title changes with the entry point (e.g. Live: "Sign in to start your free Live minutes"). Email flow: enter email → "Check your inbox" state with Resend (60 s cooldown) and "Open mail app".

### S-25 Manage subscription (P2)
```
←  Your plan
┌ Pro · monthly                  [Active] ┐   brand card
│ [PRICE]/month · billed by Google Play    │
│ Renewal: 20/11/2026                      │
└──────────────────────────────────────────┘
⚠ Google Play couldn't charge the renewal. Update payment before 27/11 to keep Pro.   (payment-issue state only)
Your benefits:  Standard 10 h/week · Live in plan 18/30 min left · Live top-up 45 min
[ Update payment ] [ Buy Live minutes ]
[ Change plan    ] [ Restore purchases ]
Purchase history:  Pro · monthly 20/10/2026 [PRICE] · 60 Live min 03/10/2026 [PRICE]
Cancel or change payment on Google Play ↗
```
State variants in doc 05 §F-15. Prices are store prices (placeholders in mockups).

### S-23 Devtools (dev only)
Engine switcher, latency HUD toggle, audio source/NS/AGC toggles, benchmark runner (select clips + engines → run → export CSV), Remote Config viewer, fake quota controls, force region-block error.

## 6. Content & tone

- **English is the source copy.** Write every string in English first (`app_en.arb`), then translate. Mockups are in English.
- Short, plain sentences; second person ("You", "Bạn").
- Always say what to do next in errors ("No internet — switched to Offline").
- Vietnamese copy uses natural, polite-neutral register ("Bạn"), no slang.
- Never use flags for languages.
- Language names appear in the UI language; pickers and pack lists add the endonym for non-Latin scripts (`Japanese · 日本語`). The partner half and the App language list use endonyms (`Tiếng Việt`).
- Dates and numbers via `intl` for the active locale (`Nov 20, 2026` in en, `20/11/2026` in vi); clock follows the phone's 12/24-hour setting.

## 7. Accessibility checklist

Labels on all icon buttons; captions announced via live region only when the user enables "Read captions aloud" (avoid TalkBack flooding); 200% text without clipping; reduce-motion disables pulses; colour is never the only signal (engine chip also has icon + text).

## 8. App icon & iconography

### 8.1 App icon — "Two sides of the table"
- Two facing speech bubbles on Lagoon: light bubble (Paper `#FAF8F4`) with a Lagoon waveform = you speaking; dark bubble (Ink `#14161F`) with Lagoon-light dots = the other person replying. A Lagoon gap separates the bubbles.
- Letter-free (no "LM" monogram), so it works in every language and survives any future rename. Recognisable at 24 px.
- Android adaptive icon: background (solid `#0F766E`), foreground (art inside the 66 dp safe zone of the 108 dp canvas), monochrome layer for themed icons (Android 13+).
- Dev flavor: same mark on Graphite `#475569` so test builds are distinguishable on the home screen.
- Google Play icon: 512×512 PNG, full-bleed square, art enlarged; no rounded corners or shadow (Play adds them).
- Notification small icon `ic_stat_lingomate`: white two-bubble silhouette on transparent (no waveform/dots — too small).
- Files and Flutter setup: `assets/brand/README.md`.

### 8.2 In-app icon set
- 79 custom icons in `assets/icons/ic_<name>.svg`: 24×24 dp grid, 2 dp stroke, round caps/joins, `currentColor`, filled variants only where state needs it (`bookmark_filled`, `star_filled`, Live dot).
- Groups: navigation (4), modes (5), engines (4), audio & controls (11), actions (27), status (10), situations (8), account & plan (10). Full inventory with intended use: `assets/icons/README.md`.
- Engine icons always appear with their chip colours (doc 08 §2.1): Offline graphite, Standard lagoon, Live on-air red with the dot pulsing.
- Implementation: one `AppIcon` widget over `flutter_svg` (`SvgPicture.asset`, `ColorFilter.mode(color, BlendMode.srcIn)`), an `AppIcons` constants class with every file name, default size 24, 20 in dense rows, 28–32 in mode cards. Every icon-only button gets a semantic label.
- Don't mix Material/Cupertino icons for anything this set covers; add new icons to the set using the same grid and stroke.


===== FILE: docs/09-decisions-and-open-questions.md =====

# 09 — Decisions & Open Questions

Status: Living document. Claude Code: treat **Decisions** as settled; ask the owner before acting on anything under **Open questions**.

## Decisions (ADR-lite)

| ID | Decision | Why | Decided by |
|----|----------|-----|------------|
| D-01 | Android first, built in Flutter | Owner has Flutter experience; Android permissions are simpler than iOS for this kind of app | Owner |
| D-02 | No custom backend server (.NET/Node). Use BaaS + third-party services; server logic only in small Cloud Functions | Owner wants to avoid building/operating a backend | Owner |
| D-03 | Firebase (not Supabase, not a mix) | Same ecosystem as Gemini; Firebase AI Logic lets the app call Gemini without a server; App Check protects quota; Supabase would need more server code and has no App Check equivalent; mixing doubles auth/consoles | Proposed by Claude, accepted |
| D-04 | Three engines — Offline, Standard, Live — behind interfaces, with auto-selection and fallback (Live → Standard → Offline) | Balances cost, quality and offline need; any engine can fail without killing the session | Proposed, accepted |
| D-05 | Meeting mode listens via microphone (phone near laptop speaker) | Android blocks third-party capture of call audio (`USAGE_VOICE_COMMUNICATION`) | Platform constraint |
| D-06 | Development phase costs $0: dev Firebase project on Spark plan, Gemini free tier, Live Translate tested with an AI Studio API key in debug builds only, no Cloud Functions in dev | Owner wants to validate features cheaply before production | Owner |
| D-07 | Standard engine = on-device ASR + Gemini Flash-Lite (via Firebase AI Logic) + on-device TTS | ~100× cheaper than Live; good quality | Proposed, accepted |
| D-08 | Live engine = `gemini-3.5-live-translate-preview` over the Live API WebSocket; production auth via ephemeral tokens from a Cloud Function | Firebase AI Logic docs don't list the Live Translate model; ephemeral tokens keep the key off the device and let us enforce quota | Proposed, accepted |
| D-09 | Usage limits work like Claude/ChatGPT: a 5-hour window + a weekly cap, per engine | Owner's idea; fair, understandable, protects margin | Owner |
| D-10 | Live quota is enforced server-side when issuing tokens (block ≤ 10 min); Standard quota is counted client-side with Firebase AI Logic per-user rate limit as safety net | Live is expensive and must be tamper-proof; Standard is cheap | Proposed, accepted |
| D-11 | Pricing is deferred. Quota numbers and plans live in Remote Config so they can change without an app update | Owner: "price can be calculated later" | Owner |
| D-12 | Publish globally. Wave-1 languages: en, vi, ja, ko, zh, th, id, es, fr, de. Per-language capability matrix. Regional price groups later | Owner wants worldwide release; wave-1 languages are supported by both Live and ML Kit | Owner |
| D-13 | Riverpod (codegen) for state/DI, go_router, Drift, freezed | Owner knows Riverpod; Drift fits relational phrasebook/SRS queries | Proposed |
| D-14 | Subscriptions via RevenueCat on top of Google Play Billing | Free until $2.5k monthly tracked revenue; avoids writing receipt validation | Proposed |
| D-15 | Privacy defaults: no audio persisted; transcripts local; cloud sync opt-in; production on Gemini paid tier | Trust and legal safety; free tier data is used to improve Google products | Proposed |
| D-16 | Docs and code in English; app UI localized (en, vi first) | Best for Claude Code and global release | Proposed |
| D-17 | Sign-in is optional: every install starts anonymous; upgrade with Google (Credential Manager) or passwordless email link; no passwords stored | Offline-first users shouldn't hit a login wall; fewer credentials to protect | Owner asked for login + profile; method proposed |
| D-18 | Live (including the free trial), purchases/restores and sync require a signed-in account; Offline, Standard free quota and local features don't | Stops trial reset by reinstalling; stable identity for entitlements and quotas | Proposed |
| D-19 | Account deletion available in-app and via a web page; deletes Auth user, Firestore data, usage, RevenueCat customer | Required by Google Play's account deletion policy | Policy |
| D-20 | Subscription management screen in-app (status, benefits, history); cancel/payment changes happen in Google Play via `managementURL` | Android has no native manage-subscription sheet; Play owns billing | Owner asked for a subscription screen |
| D-21 | App icon = letter-free "two facing bubbles" mark on Lagoon (dev flavor on Graphite); custom 79-icon SVG set (24 dp, 2 dp stroke) instead of Material icons | Survives a rename; one consistent visual language; engine icons match chip colours | Owner asked for icons; design proposed |
| D-22 | English is the default and source UI language. The app follows the phone's language when supported (launch: en, vi), otherwise English; users can change it in-app (Me → App language, Welcome) and in Android 13+ system settings. Mockups and the master store listing are in English | Global release, consistent professional copy; Vietnamese stays a first-class translation | Owner |
| D-23 | Figma is the visual source of truth (file "Lingo Mate — UI Design"); doc 08 stays the source for behaviour, states and tokens. AI tools read the design straight from the Figma link (Figma MCP); `design/` PNG/HTML exports are an offline fallback only. The claude.ai canvas is archived | Owner wants to view, edit and share the design in Figma and hand the Figma link to AI tools | Owner |
| D-24 | App name: **Lingo Mate** (display name; `lingomate` in ids, e.g. Firebase projects `lingomate-dev` / `lingomate-prod`, notification icon `ic_stat_lingomate`). Replaces the working title "Parley" | Owner's chosen name | Owner |
| D-25 | Package id `com.lingomate.app` for production; `com.lingomate.app.dev` and `com.lingomate.app.staging` for the other flavors. Env files are plain `KEY=VALUE` files in the project root (`.env.dev` dev, `.env.staging` staging, `.env` production), not JSON | Firebase apps are registered by package id; one env format across flavors and CI | Owner |

## Open questions

| ID | Question | Why it matters | How/when to resolve |
|----|----------|----------------|---------------------|
| OQ-1 | What concrete situation made the owner want this app (the core pain point)? | Decides which mode is the hero of P1 and which spike experiment runs first | Owner, before P1 starts |
| OQ-2 | Final prices and quota numbers per plan | Margin; working draft below | After beta usage data (A-3) |
| OQ-3 | Which on-device ASR library: whisper.cpp wrapper, transcribe_cpp, or sherpa-onnx? Which model size? | Latency, accuracy (esp. Vietnamese), APK/model size, battery | Phase 0 spike (T-0.4) |
| OQ-4 | Is the "two Live sessions on one mic stream" approach viable for two-way conversation? | Two-way Live quality and cost (+~$0.0053/min) | Phase 0 spike (T-0.5) |
| OQ-5 | `gemini-3.1-flash-live-preview` is now labelled legacy; Google points to `gemini-3.8-live`. Price? Firebase AI Logic support? | Fallback Live model choice | Phase 0 spike |
| OQ-6 | Does Firebase AI Logic support the Live Translate model + `translationConfig`? | If yes, the token function may be unnecessary | Re-check docs at P2 start |
| OQ-7 | Store-name/trademark check for "Lingo Mate" (an iOS app named "LingoMate: Offline Translator" already exists). Package id is settled (D-25) | Store listing, avoiding confusion or a takedown | Owner, before first Play upload |
| OQ-8 | Play Console account type: personal (closed test ≥ 12 testers × 14 days) or organization (needs D-U-N-S) | Launch timeline | Owner, before P2 |
| OQ-9 | Tax treatment of app revenue in Vietnam | Net margin (draft assumes 10% reserve) | Owner + accountant |
| OQ-10 | Exact raw-WebSocket parameter for authenticating with an ephemeral token | Implementation detail of F-05 Live in prod | Phase 2 start; verify against docs |
| OQ-11 | Regions where Gemini API is blocked: accept Offline-only, or later route through Agent Platform (Vertex AI) with a proxy? | Coverage vs. "no server" decision | Revisit after P3 |
| OQ-12 | Should sign-in + profile ship in P1 (internal alpha) instead of P2? Plan currently keeps P1 login-free | Earlier login = earlier sync/Live testing, but more P1 scope | Owner, before P1 starts |
| OQ-13 | Add Sign in with Apple when the iOS app starts? (App Store review rules ask for an equivalent privacy-friendly login option when third-party logins are offered — verify current guideline) | iOS parity | When iOS is planned |

## Pricing working draft (NOT final — see OQ-2)

Assumptions: 1 USD = 26,000 VND; net = 76.5% of price (Google Play 15% on subscriptions + 10% tax reserve); Live two-way ≈ 1,095 VND/min; Standard ≈ 19 VND/min (≈ 1,100 VND/hour, conservative estimate).

"Max-usage-safe" structure (no loss even if a user maxes out every cap):

| Plan | Price | Includes (caps) | Max AI cost | Profit at max |
|------|-------|-----------------|-------------|---------------|
| Free | 0 | Offline unlimited; Standard 30 min per 5h window, 1 h/week; Live 10 min one-time trial | ~4,800 VND/mo (+ ~11,000 one-time) | marketing cost |
| Pro Lite | 49,000 VND/mo | Standard 6 h/week; no Live | ~28,900 VND | ~+8,600 VND |
| Pro (VN) | 119,000 VND/mo · 1,290,000 VND/yr | Standard 10 h/week; Live 30 min/month | ~81,000 VND | ~+10,000 (monthly) · ~+1,300 (yearly) |
| Pro (group A: US/EU/JP/KR/AU/SG) | $7.99/mo · $69.99/yr | same caps | ~81,000 VND | ~+78,000 (monthly) · ~+35,000 (yearly) |
| Live top-up | 69,000 VND / 30 min · 119,000 VND / 60 min | prepaid minutes | — | ~+20,000 · ~+25,000 |

Sensitivity: if Flash-Lite 2.5 is retired and Standard moves to `gemini-3.1-flash-lite` ($0.25 in / $1.50 out per 1M tokens), Standard cost rises ~2.6×; re-run the numbers.


===== FILE: design/README.md =====

# design — Lingo Mate UI

**Source of truth for visuals: Figma** — https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k (file "Lingo Mate — UI Design", page "Lingo Mate UI v0.1", one Section per group). UI copy is English (D-22). Screen behaviour, states and tokens are specified in `docs/08-design-system.md`, which wins if the two differ (D-23).

**Read the design from Figma** (frame links below). This folder only holds offline copies (v0.1) for when Figma is unreachable or the Figma MCP read quota runs out; if they differ, Figma wins.

| Path | What |
|------|------|
| `screens/S-xx-*.png` | Every phone screen at 2× (780×1688; layout is 390×844 dp) |
| `html/S-xx-*.html` | HTML source of each screen — exact colours, sizes, spacing, copy. Open in a browser; links between screens work |
| `boards/app-icon.png`, `boards/icon-set.png` | App icon sheet and the 79-icon set |
| `index.html` | Gallery of all screens (open in a browser) |
| `LingoMate-UI-Design.pdf` | Same gallery as a PDF, for reading and sharing |

## Screens

| ID | Export name | Figma frame | Phase notes |
|----|-------------|-------------|-------------|
| S-01 | `S-01-welcome` | [2:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=2-2) | App language selector top-right (F-11) |
| S-04 | `S-04-translate-home` | [3:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=3-2) | |
| S-05 | `S-05-conversation` | [4:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=4-2) | Partner half in the partner's language |
| S-06 | `S-06-listen` | [5:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=5-2) | Offline fallback banner state |
| S-07 | `S-07-meeting` | [6:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=6-2) | Suggest reply / Summarize are P2 |
| S-08 | `S-08-caption-overlay` | [7:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=7-2) | System overlay over another app |
| S-10 | `S-10-transcript` | [8:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=8-2) | Summary card and "How would a native say it?" are P2 |
| S-13 | `S-13-quick-phrases` | [9:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=9-2) | |
| S-14 | `S-14-situation` | [10:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=10-2) | |
| S-15 | `S-15-show-mode` | [11:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=11-2) | |
| S-11 | `S-11-phrasebook` | [12:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=12-2) | Review banner is P2 |
| S-16 | `S-16-language-packs` | [13:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=13-2) | |
| S-18 | `S-18-usage` | [14:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=14-2) | P2 |
| S-19 | `S-19-paywall` | [15:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=15-2) | P2; prices are placeholders (OQ-2) |
| S-24 | `S-24-sign-in` | [16:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=16-2) | P2; Google button needs official branding |
| S-17 | `S-17-me-profile` | [17:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=17-2) | Account + plan cards are P2 (hidden in P1) |
| S-25 | `S-25-manage-subscription` | [18:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=18-2) | P2; billing-issue state shown |
| — | `boards/app-icon` | [19:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=19-2) | App icon sheet |
| — | `boards/icon-set` | [20:2](https://www.figma.com/design/LiWdCOSttvpVyobtwLQv0k?node-id=20-2) | 79-icon set (production SVGs are in `assets/icons/`) |

Screens not drawn (S-02, S-03, S-09, S-12, S-20–S-23) are specified in doc 08 §5 only.

## How to use these when building (Claude Code)

1. Read the screen's spec in `docs/08-design-system.md` (states, components, tokens).
2. Open the screen's Figma frame (link in the table) with the Figma MCP server (`get_design_context`, `get_screenshot`) for layout, exact values and copy.
3. Fallback only: `screens/<id>.png` (look) and `html/<id>.html` (exact values).
4. Rebuild in Flutter with the theme tokens and components from doc 08 (`lib/app/theme/`, `AppIcon` + `assets/icons/`). Do not port the HTML structure or inline styles.
5. Sample content (Alex Morgan, "Client meeting", phrases, numbers, prices) is placeholder; real text comes from `app_en.arb` and real data.
6. Build P2 elements only in Phase 2 (see the table above).
7. Figma MCP setup: connect the Figma MCP server in your AI tool (Claude Code: `claude mcp add` with Figma's remote server, then sign in). The owner's Figma Starter plan has a small monthly MCP read quota — read each screen once per task and reuse the result instead of re-reading.

## Updating

Edit the design in Figma. When a screen changes, re-export its PNG (Figma: select frame → Export → PNG 2×, name `S-xx-*.png`) into `screens/`, update doc 08 if behaviour changed, and commit both together. The HTML sources reflect the v0.1 mockups and are not regenerated from Figma; when they drift, Figma + PNG win.


===== FILE: assets/brand/README.md =====

# assets/brand — Lingo Mate app icon

Concept **"Two sides of the table"**: two facing speech bubbles. The light bubble (paper) is you speaking (waveform); the dark bubble (ink) is the other person replying (dots). No letters, so the mark works in every language and survives any future rename.

Colours: Lagoon `#0F766E` (background) · Ink `#14161F` · Paper `#FAF8F4` · Lagoon light `#2DD4BF`. Dev flavor uses Graphite `#475569` as background so test builds are easy to tell apart.

## Files

| File | What | Use |
|------|------|-----|
| `ic_launcher_background.svg` / `png/icon_background_1024.png` | Solid Lagoon, 108×108 canvas | Adaptive icon background |
| `ic_launcher_foreground.svg` / `png/icon_foreground_1024.png` | Bubbles on transparent, art inside the 66 dp safe zone | Adaptive icon foreground |
| `ic_launcher_monochrome.svg` / `png/icon_monochrome_1024.png` | Single-colour (white) silhouette with cut-outs | Themed icons (Android 13+) |
| `ic_launcher_foreground_dev.svg` / `png/icon_foreground_dev_1024.png`, `ic_launcher_background_dev.svg` | Dev variant (gap colour + background graphite) | `dev` flavor |
| `app_icon_full.svg` | Background + foreground composited (108 canvas) | Previews |
| `play_store_icon.svg` / `png/play_store_icon_512.png` | Full-bleed square, art enlarged | Play Console store icon (512×512, 32-bit PNG, ≤ 1 MB; no rounded corners or shadow — Play adds them) |
| `png/app_icon_1024.png`, `png/app_icon_dev_1024.png` | Full-bleed composite | `image_path` for flutter_launcher_icons |
| `ic_stat_lingomate.svg` / `png/ic_stat_lingomate_<density>_<px>.png` | White silhouette on transparent, 24 dp | Notification small icon (foreground service, reminders) |

Adaptive icon rules followed: all layers 108×108 dp; important art inside the centred 66 dp circle; background fully opaque; monochrome layer provided.

## Flutter setup (T-1.1)

`pubspec.yaml` (dev dependency `flutter_launcher_icons`) — one config per flavor, e.g. `flutter_launcher_icons-prod.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  min_sdk_android: 26
  image_path: "assets/brand/png/app_icon_1024.png"
  adaptive_icon_background: "#0F766E"
  adaptive_icon_foreground: "assets/brand/png/icon_foreground_1024.png"
  adaptive_icon_monochrome: "assets/brand/png/icon_monochrome_1024.png"
```

`flutter_launcher_icons-dev.yaml`: same keys with `app_icon_dev_1024.png`, background `#475569`, foreground `icon_foreground_dev_1024.png`. Run `dart run flutter_launcher_icons -f flutter_launcher_icons-<flavor>.yaml` (check key names against the plugin version you install).

Notification icon: copy `png/ic_stat_lingomate_<density>_<px>.png` to `android/app/src/main/res/drawable-<density>/ic_stat_lingomate.png` (or import `ic_stat_lingomate.svg` with Android Studio → Vector Asset), then reference `@drawable/ic_stat_lingomate` from the foreground-service notification. Never use the colour launcher icon as a notification icon.

Splash (Android 12+ system splash): background `#0F766E`, icon = adaptive foreground.


===== FILE: assets/icons/README.md =====

# assets/icons — Lingo Mate in-app icon set

Grid 24×24 dp · stroke 2 dp · round caps & joins · `currentColor` (tint in code) · 2 dp optical padding.
Render with `flutter_svg`: `SvgPicture.asset('assets/icons/ic_mic.svg', width: 24, colorFilter: ColorFilter.mode(color, BlendMode.srcIn))`.
Wrap in one `AppIcon(AppIcons.mic)` widget; never mix in Material icons for things this set covers.

| File | Label | Group | Use |
|------|-------|-------|-----|
| `ic_nav_translate.svg` | Translate | nav | Bottom nav — Translate tab |
| `ic_nav_phrases.svg` | Phrases | nav | Bottom nav — Phrases tab |
| `ic_nav_history.svg` | History | nav | Bottom nav — History tab |
| `ic_nav_me.svg` | Me | nav | Bottom nav — Me tab, avatar fallback |
| `ic_mode_conversation.svg` | Conversation | mode | Conversation mode card/entry |
| `ic_mode_listen.svg` | Listen | mode | Listen mode |
| `ic_mode_meeting.svg` | Meeting | mode | Meeting mode |
| `ic_mode_media.svg` | Media | mode | Media capture mode (P3) |
| `ic_mode_show.svg` | Show mode | mode | Show mode |
| `ic_engine_offline.svg` | Offline | engine | Engine chip — on-device |
| `ic_engine_standard.svg` | Standard | engine | Engine chip — Standard (cloud text) |
| `ic_engine_live.svg` | Live | engine | Engine chip — Live (pulse the dot) |
| `ic_engine_unavailable.svg` | Unavailable | engine | Engine chip — unavailable |
| `ic_mic.svg` | Mic | audio | Mic button |
| `ic_mic_off.svg` | Mic off | audio | Mic muted / permission denied |
| `ic_waveform.svg` | Listening | audio | Listening indicator |
| `ic_stop.svg` | Stop | audio | Stop session |
| `ic_pause.svg` | Pause | audio | Pause |
| `ic_play.svg` | Play | audio | Resume / play |
| `ic_speaker.svg` | Speak | audio | Speak (TTS), TTS on |
| `ic_speaker_off.svg` | Voice off | audio | TTS off |
| `ic_replay.svg` | Replay | audio | Replay last translation |
| `ic_auto_turn.svg` | Auto-detect | audio | Conversation auto mode |
| `ic_swap.svg` | Swap languages | audio | Swap language pair |
| `ic_bookmark.svg` | Save | action | Save to phrasebook |
| `ic_bookmark_filled.svg` | Saved | action | Saved state |
| `ic_star.svg` | Favorite | action | Favorite |
| `ic_star_filled.svg` | Favorited | action | Favorite on |
| `ic_copy.svg` | Copy | action | Copy text |
| `ic_share.svg` | Share | action | Share transcript |
| `ic_delete.svg` | Delete | action | Delete |
| `ic_edit.svg` | Edit | action | Edit / rename |
| `ic_add.svg` | Add | action | Add phrase / term |
| `ic_search.svg` | Search | action | Search |
| `ic_filter.svg` | Filter | action | Filter lists |
| `ic_close.svg` | Close | action | Close / cancel |
| `ic_back.svg` | Back | action | Back |
| `ic_chevron_right.svg` | Open | action | Row chevron |
| `ic_chevron_down.svg` | Dropdown | action | Dropdown |
| `ic_more.svg` | More | action | Overflow menu |
| `ic_external.svg` | External link | action | Opens Google Play / browser |
| `ic_download.svg` | Download | action | Download pack |
| `ic_expand.svg` | Expand | action | Expand overlay / show large |
| `ic_rotate.svg` | Rotate | action | Rotate for partner |
| `ic_text_size.svg` | Text size | action | Caption size |
| `ic_language.svg` | Language | action | Language picker |
| `ic_suggest_reply.svg` | Suggest reply | action | Suggested replies (P2) |
| `ic_summarize.svg` | Summarize | action | Session summary (P2) |
| `ic_review_cards.svg` | Review | action | SRS review (P2) |
| `ic_glossary.svg` | Glossary | action | Glossary (P2) |
| `ic_tag.svg` | Tag | action | Tags |
| `ic_check.svg` | Ready | status | Ready / success |
| `ic_info.svg` | Info | status | Info banner |
| `ic_warning.svg` | Warning | status | Warning banner, payment issue |
| `ic_error.svg` | Error | status | Error banner |
| `ic_wifi_off.svg` | No internet | status | No internet |
| `ic_region_blocked.svg` | Region blocked | status | Cloud unavailable in region |
| `ic_lock.svg` | Lock | status | Privacy promise |
| `ic_privacy.svg` | Privacy | status | Privacy & data settings |
| `ic_sync.svg` | Sync | status | Sync status |
| `ic_timer.svg` | Timer | status | Live minutes, reset time |
| `ic_sit_airport.svg` | Airport | situation | Quick phrases — Airport |
| `ic_sit_hotel.svg` | Hotel | situation | Quick phrases — Hotel |
| `ic_sit_restaurant.svg` | Restaurant | situation | Quick phrases — Restaurant |
| `ic_sit_taxi.svg` | Taxi & directions | situation | Quick phrases — Taxi & directions |
| `ic_sit_shopping.svg` | Shopping | situation | Quick phrases — Shopping |
| `ic_sit_health.svg` | Health & emergency | situation | Quick phrases — Health & emergency |
| `ic_sit_smalltalk.svg` | Small talk | situation | Quick phrases — Small talk |
| `ic_sit_meeting.svg` | Meeting basics | situation | Quick phrases — Meeting basics |
| `ic_email.svg` | Email | account | Continue with email |
| `ic_pro.svg` | Pro | account | Plan badge |
| `ic_payment.svg` | Payment | account | Update payment |
| `ic_receipt.svg` | Receipt | account | Purchase history |
| `ic_usage.svg` | Usage | account | Usage sheet |
| `ic_streak.svg` | Streak | account | Review streak |
| `ic_settings.svg` | Settings | account | Translation & voice settings |
| `ic_help.svg` | Help | account | Help & feedback |
| `ic_logout.svg` | Sign out | account | Sign out |
| `ic_delete_account.svg` | Delete account | account | Delete account |
