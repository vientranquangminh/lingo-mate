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
