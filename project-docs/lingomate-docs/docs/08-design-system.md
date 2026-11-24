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
