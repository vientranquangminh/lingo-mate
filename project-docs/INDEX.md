# project-docs — lookup index

Where to find product information for Lingo Mate. The canonical copies live in
`lingomate-docs/`; the `*.md` files directly in `project-docs/` are identical copies of
`lingomate-docs/docs/*`, `lingomate-docs/CLAUDE.md` and the folder READMEs.

ID prefixes used across the docs: `F-xx` feature, `AC-xx.y` acceptance criterion, `S-xx`
screen, `T-x.y` plan task, `D-xx` decision, `OQ-xx` open question.

## By question

| Looking for | File (under `lingomate-docs/`) |
|---|---|
| Vision, target users, use cases, goals, constraints, glossary | `docs/01-project-spec.md` |
| Phases, milestones, task IDs (`T-x.y`), risks | `docs/02-project-plan.md` |
| Architecture, stack, engines, audio pipeline, data model, quota engine, Remote Config keys, security, flavors | `docs/03-technical-design.md` |
| Firebase, Gemini text and Live API, ML Kit, on-device ASR, TTS, Auth/Firestore, Cloud Functions, RevenueCat, Play Console | `docs/04-integrations.md` |
| Feature catalogue `F-01`…`F-24` with phase and priority | `docs/05-feature-specs.md` |
| User stories and acceptance criteria per feature | `docs/06-feature-details-acs.md` |
| Test levels, fakes, benchmark protocol, device matrix, release checklist | `docs/07-test-plan.md` |
| Design tokens, components, navigation, screen specs, tone, accessibility | `docs/08-design-system.md` |
| Settled decisions (`D-xx`), open questions (`OQ-xx`), pricing draft | `docs/09-decisions-and-open-questions.md` |
| Accounts, tools, secrets, devices, budget (owner checklist) | `docs/00-preparation.md` |
| Figma link and per-screen frame links | `design/README.md` |
| Screen images (`S-xx`) | `design/screens/*.png`, `design/html/*.html`, `design/LingoMate-UI-Design.pdf` |
| App icon, launcher, notification and Play icons | `assets/brand/` (see its `README.md`) |
| In-app SVG icons and inventory | `assets/icons/` (see its `README.md`) |
| Everything above in one file | `LingoMate-AI-Context.md` |

## Precedence

`lingomate-docs/CLAUDE.md` was written for a fresh repo. Where it disagrees with the
repository's root `CLAUDE.md` or `.agents/CONTEXT.md` on code conventions (Flutter via
`fvm`, `intl_en.arb`, shared widgets, state and DI patterns), the root files win. For product
behaviour, scope and decisions, these docs are the source of truth.
