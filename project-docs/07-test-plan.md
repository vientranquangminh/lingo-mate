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
