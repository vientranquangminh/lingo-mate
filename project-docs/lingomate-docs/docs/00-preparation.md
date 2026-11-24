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

```
env/
  dev.example.json   # committed
  dev.json           # NOT committed
```
```json
{
  "GEMINI_API_KEY": "AIza...",
  "FLAVOR": "dev",
  "LIVE_ENABLED": "true"
}
```
- `.gitignore`: `env/*.json` except `*.example.json`, `android/app/src/*/google-services.json` if you prefer, `test_assets/audio/*.wav` (if large/private).
- Prod builds never receive `env/dev.json`. CI secret scan fails on `AIza` in release artifacts.

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
- App name is decided: **Lingo Mate** (D-24); app icon ready in `assets/brand/`. Before the first Play upload: choose the package id and check the store name/trademark (OQ-7).

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
2. Put `env/dev.json` and Firebase config files in place (Claude Code can run FlutterFire CLI with you).
3. First prompt (example):

```
Read CLAUDE.md and all files in docs/. Then do Phase 0 task T-0.1 from docs/02-project-plan.md:
bootstrap the Flutter project with dev/prod flavors, Riverpod codegen, go_router, Drift, lints and the
GitHub Actions CI described in docs/03-technical-design.md §15. Stop after T-0.1 and show me what you
created and how to run it. Ask me before deviating from the docs.
```
4. Continue task by task (T-0.2, T-0.3 …), reviewing each PR on a real device.
