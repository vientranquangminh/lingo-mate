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
