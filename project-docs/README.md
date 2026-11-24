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
