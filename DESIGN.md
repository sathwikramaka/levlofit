# DESIGN.md: Levlofit

Design system for Levlofit, the India-first fitness app and its marketing website. Format follows [awesome-design-md](https://github.com/voltagent/awesome-design-md).

Visual reference: hi-fi prototype and Levlofit logo lab at https://claude.ai/artifact/MDfxJQhEN1Zc5P7kPkgmDy

## 1. Visual Theme & Atmosphere

Dark-first, simple and classic: graphite, one orange, warm white. The orange is rare on purpose, so when it appears it means "act here" or "you levelled up". Calm, confident and evidence-first: every number on screen can point to a source.

Mood words: focused, warm, premium, earned, precise.

Brand idea: **find your level**. The logo is a spirit level's bubble (the orange dot) resting in the corner of an L. Levels 0 to 5 are earned, never given.

## 2. Color Palette & Roles

One accent only. No gradients, no second accent colour.

| Token | Light | Dark | Role |
|---|---|---|---|
| `bg` | `#F0EEE9` Cloud Dancer | `#0E0E10` Graphite | Page background |
| `surface` | `#FFFFFF` | `#18181B` | Cards, sheets, inputs |
| `surface-2` | `#E6E3DC` | `#222226` | Tracks, placeholders, quiet panels |
| `ink` | `#0E0E10` | `#F0EEE9` | Text, outline buttons, selected states |
| `on-ink` | `#F0EEE9` | `#0E0E10` | Text on `ink` fills |
| `muted` | `#5B5953` | `#9A9690` | Secondary text (6.0 : 1 light, 6.5 : 1 dark) |
| `border` | `#D9D5CC` | `#2A2A2E` | Hairlines |
| `accent` | `#FF6A1A` Levlofit Orange | `#FF6A1A` | Fills only: the bubble, the one primary action, progress, level-ups, PRs |
| `on-accent` | `#0E0E10` | `#0E0E10` | Text on orange (6.7 : 1). Never white on orange (2.9 : 1 fails) |
| `accent-text` | `#B8420B` | `#FF8A4C` | Orange used as text or links (4.7 : 1 light, 8.2 : 1 dark) |
| `success` | `#2F7D4F` | `#5FB482` | Done states, checks |
| `danger` | `#B3261E` | `#F2766B` | Errors, destructive confirm |

Rules:
- About 60 % graphite or white, 30 % ink and surfaces, 10 % orange at most.
- Orange appears once per screen as an action, plus the bubble and reward moments.
- Meaning is never colour alone: pair it with an icon or label.

Why this orange: Strava owns red-orange `#FC4C02` and is shown on white. Levlofit Orange is purer and warmer, and lives on graphite. The combination (orange + dark + the bubble) is what is ownable.

## 3. Typography Rules

| Use | Typeface | Notes |
|---|---|---|
| Wordmark, splash, level-up moments, website hero | **Unbounded** 700 | Wide and rounded. Letter spacing -0.02 to -0.03 em. Not for body or long headings in the app |
| App UI, headings, body | **Geist** 400 to 700 | Headings 700 with -0.02 to -0.03 em |
| Numbers, labels, data | **Geist Mono** 400 to 500 | Uppercase labels at 11 px with 0.14 em tracking |
| Handbook long-form reading | **Noto Serif** (Noto Serif Devanagari for Hindi) | 16 to 17 px, line-height 1.6 |
| Hindi / Devanagari UI | **Anek Devanagari** | Geist has no Devanagari; use Anek as the fallback |

| Style | Size / line-height |
|---|---|
| Hero (web, Unbounded) | 56 to 96 / 0.95 |
| H1 (app, Geist 700) | 28 to 34 / 1.1 |
| H2 | 22 to 24 / 1.2 |
| Body | 15 to 16 / 1.5 |
| Label | 13 to 14 / 1.3 |
| Caption | 12 to 13 / 1.45, `muted` |

Tabular numbers everywhere a number changes (`font-variant-numeric: tabular-nums`). Minimum 12 px for anything, 14 px for body.

## 4. Logo

- **Mark (L·o):** an L with the orange bubble resting in its corner. L is `ink` (chalk on dark, graphite on light); the bubble is always Levlofit Orange. On an orange background only, the bubble turns Cloud Dancer.
- **Wordmark:** `levl` + an orange bubble (the o) + `fit`, in Unbounded 700: reads "levlofit". Always lowercase, one word, bubble never replaced by a letter. Renamed from Levlo on 2026-09-29 (name clash with an Amazon brand and levlo.com).
- **Files:** `brand/levlo-icon.svg` (app icon master, graphite tile), `brand/levlo-mark-on-dark.svg`, `brand/levlo-mark-on-light.svg`. Website favicon: `website/src/app/icon.svg`.
- **Minimum size:** 16 px for the mark, 80 px wide for the wordmark. Clear space = one bubble diameter on every side.
- **Motion:** the bubble slides in, overshoots slightly and settles (about 1 s, spring ease `cubic-bezier(0.32, 0.72, 0, 1)`). Used for splash, loading and level-up. Static under reduced motion.
- **Never:** rotate, stretch, outline, add gradients or shadows, recolour the bubble (except on orange), or put the mark on busy photos.

## 5. Component Stylings

- **Primary button:** orange fill, graphite text, 48 px tall (44 px minimum), radius 12, weight 700. One per screen.
- **Secondary button:** transparent, 1 px `ink` border, `ink` text, radius 12.
- **Inputs:** 48 px, radius 12, 1 px `border`, `surface` fill. Label above, helper or error text below (error: 1.5 px `danger` border + `aria-invalid`). Password fields always have a show/hide toggle.
- **Chips / choices:** radius 10, 52 px minimum height. Selected = `ink` fill with a check; the primary goal gets a small orange tag. Disabled = dashed border plus a text label.
- **Cards:** `surface`, radius 16, hairline border, no shadow in the app. Marketing pages may use the double-bezel frame (outer tray + inner core).
- **Progress:** rings and bars in orange on `surface-2` tracks. Level ladders: `ink` = passed, orange = current.
- **Rule and evidence boxes:** full hairline border (rule) or `surface-2` fill (evidence) with an uppercase Geist Mono label. Never a coloured left stripe.
- **Bottom nav:** 5 items maximum, icon plus label, active item `ink` and bold.
- **Icons:** thin-stroke line icons (1.5 px, e.g. Lucide at 1.5 or Phosphor Light), 20 to 22 px. Icon-only buttons need `aria-label`. No emoji.
- **Modals:** confirmation required for destructive actions (delete account, clear logs); destructive button uses `danger`.

## 6. Layout Principles

- Spacing scale: 4, 8, 12, 16, 20, 24, 32, 48, 64, 96.
- App: 20 to 24 px side gutters, 16 px between cards, one column.
- Web: 80 px gutters on desktop, 16 px on phones, max content 1280 px, 12-column grid, generous section padding (96 px+).
- One primary (orange) action per screen or section.

## 7. Depth & Elevation

Flat. Separation comes from hairlines and the graphite / surface step, not shadows. Floating layers (sheets, modals, cookie banner, floating contact button) may use one soft shadow; modals sit on a 60 % graphite scrim.

## 8. Do's and Don'ts

Do:
- Cite the source under every number (protein targets, food limits, level criteria).
- Use real Indian foods (dal, roti, rajma, paneer, eggs, soya chunks).
- Show loading, empty, error and success states for every form and list.
- Respect `prefers-reduced-motion` and system dark mode.

Don't:
- Gradients, a second accent colour, purple anything, pill-shaped buttons.
- Fake reviews, fake metrics, customer counters, invented stats.
- Emoji as icons, em dashes in product copy, vague hero lines.
- AI stock photos, cursor effects, scroll-jacking.
- Beef or pork anywhere in food content.
- Inter, Roboto or Arial as the visible typeface.

## 9. Responsive Behavior & Agent Prompt Guide

- Breakpoints 375, 768, 1024, 1440. Touch targets at least 44 x 44 px with 8 px spacing.
- Motion 150 to 250 ms for UI, ease-out on enter, exits faster; animate only opacity and transform.
- Flutter: map tokens into `ColorScheme` (light + dark) and a `TextTheme`; support text scaling to 200 % without clipping.
- Web: CSS variables on `:root` with a `[data-theme="dark"]` override plus `prefers-color-scheme`; print stylesheet hides nav, banners and floating buttons.

When building UI for this project:
1. Read this file first; use only these tokens and typefaces.
2. Orange = one primary action, the bubble, progress and rewards. Nothing else.
3. Every data screen needs loading, empty, error and success states.
4. Every fitness or nutrition number comes from the plan engine or a cited Handbook source, never from the UI layer.
5. Copy: plain, specific, second person, no em dashes, no hype.
6. Check contrast (4.5 : 1 body, 3 : 1 large text) and keyboard / screen-reader access, then run Playwright CLI for console errors on web pages.
