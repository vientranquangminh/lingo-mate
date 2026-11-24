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
