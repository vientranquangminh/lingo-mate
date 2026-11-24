# CLAUDE.md — Lingo Mate

Lingo Mate is an Android-first Flutter app for **live speech translation**: face-to-face conversations (online or offline), one-way listening (lectures, tours), and online meetings heard through the phone mic, with a personal phrasebook, quick phrases by situation, and learning features built from the user's own conversations.

The app is called **Lingo Mate** (D-24). The package id and the final store-name/trademark check are still open (OQ-7).

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

- **No secrets in release builds.** The Gemini API key is allowed only in the `dev` flavor via `--dart-define-from-file=env/dev.json`. Production Live sessions use ephemeral tokens from the `issueLiveToken` Cloud Function. CI must fail if a release build contains `AIza` strings.
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
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
flutter run --flavor prod -t lib/main_prod.dart

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
