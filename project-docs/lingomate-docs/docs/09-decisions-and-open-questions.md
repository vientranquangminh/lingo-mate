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
| D-26 | Sign-in and profile stay in Phase 2; the Phase 1 internal alpha has no sign-in (closes OQ-12) | Keeps P1 scope on the core translation modes; Live and sync, which need an account, are P2 anyway (D-18) | Owner |

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
