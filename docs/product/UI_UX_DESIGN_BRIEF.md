# Levlofit: UI/UX Design Brief

Last updated: 2026-11-12, for release 1.1.1. Keep current: see "Keeping these documents current" in `CLAUDE.md`.
Tokens and logo rules in full: `DESIGN.md`. Code: `app/lib/theme.dart`.

## 1. Direction

Calm, plain and easy to scan: white cards on soft grey, one accent, and the next action obvious. Premium and trustworthy
for Indian users, and never looking AI-made. Redesigned 2026-11-07 at the owner's request after reviewing Apple Fitness,
Google Fit and Google Health, and the strength loggers Hevy and Strong. Patterns were learned from them; the look, words
and data are Levlofit's own.

What the review changed:

| Pattern seen | What Levlofit does |
|---|---|
| Apple Fitness and Google Health: a few fixed bottom tabs, and a first screen you can customise | Five named tabs that never move: Today, Workout, Diet, Progress, More. Today's cards can be reordered or hidden |
| Google Health: a weekly target beside the day's plan | Two weekly rings, training days and active minutes (WHO), with plain numbers beside them |
| Hevy and Strong: open, tap the routine, start lifting | Workout opens on today's session. A session opens on its exercises, with warm-up folded |
| Coach inside the app, not on top of it | Levlofit AI is a button at the top of the main tabs and a row in More; it no longer floats over content |
| Rank and rating belong with results | Rank, rating and the 66-day challenge moved from Today to Progress |

Not copied: Apple's three coloured rings, Google's names, any layouts or artwork.

Principles: one clear next action per screen; useful information before decoration; real data only; no guilt; every
number has a label or unit.

## 2. Colour

| Role | Light | Dark |
|---|---|---|
| Page | `#ECECEE` | `#0E0E10` |
| Card | `#FFFFFF` | `#18181B` |
| Track, quiet panel | `#E1E1E4` | `#222226` |
| Text | `#0E0E10` | `#F0EEE9` |
| Muted text | `#5C5C63` | `#9A9690` |
| Accent, orange | `#FF6A1A` | `#FF6A1A` |
| Orange as text | `#B8420B` | `#FF8A4C` |
| Progress and done, green | `#7DB86A` | `#8CC67A` |
| Bar, filled panels | `#3A3A3E` charcoal | `#2A2A2E`, panels `#18181B` |

Text on orange is dark, never white. Orange marks the main action, level and rank progress, and the bubble. Green only
for progress and done, always with a number or label. No other accents.

## 3. Type

Geist everywhere in the app; numbers with tabular figures. Unbounded for the wordmark and moment numbers (level up, share card). Noto Serif for long Handbook
reading. Headings 22 to 30 px bold, body 15 to 16, captions 13, small uppercase labels 12 with light tracking. 12 px minimum.

## 4. Shape and motion

- Cards 28 px radius, hairline border, no heavy shadow. Pills for buttons and chips; inputs 18 px.
- One soft fade, charcoal into the page, behind the AI coach header only. No other gradients.
- Motion: gentle rise and fade, numbers count up, arcs draw in. Off under reduced motion.

## 5. Components

| Component | Rule |
|---|---|
| Bottom bar | Docked; five named tabs in fixed positions; current tab has a soft orange mark behind its icon and a bolder name |
| Activity card | Grey panel with two arcs, white stats panel beside it |
| Tiles | Label, big number, short caption; half-width tiles pair up |
| Plate meal card | Plate picture, name and time, kcal and protein, servings; tap for grams; Swap and Ate it |
| Info card | Label plus short lines: training day, supplements |
| Coach | Your messages in charcoal, replies on white cards, pill composer |
| Levlofit AI button | Floating, bottom right: the Levlofit AI robot (FitBotPainter) on a 62 dp charcoal disc (cloud in dark mode), bobbing and blinking, a soft orange ring pulsing out; still with reduced motion; no text, name on long press |
| Activity map | 53 weeks of squares, Monday on top, green in four strengths by minutes trained, today ringed in orange text colour |
| Book figures | Drawn, never images: stat tiles, numbered steps, do (green) and avoid, bars, a donut plate, yes and no flows, ranges, scales; a short note sits at the row end, a sentence goes under it; cites as [n] in tertiary; fit a 320 dp phone |
| Healthy plate check | Three thin bars on Diet's day totals: share by weight and the aim; green inside the aim, orange outside, with one plain fix line |
| Plan tables | Meal and day tables: item left, numbers right in Geist tabular figures, hairline rows, a total row on a faint orange tint with orange numbers |
| Dark panels | Water, Habits, Progress verdict: charcoal, light text |
| Moments | Level up: full screen, mark, Unbounded level number, Share and Continue. New best: heavy haptic and a short note. No confetti |
| Share card | Square, always dark, wordmark, one big line, up to three facts; never food or weight |
| Home widget | Graphite, 20 dp corners, orange-text label, cloud title, muted line |

## 6. Words

Plain English, short, specific. Never shame a missed day. Say what is missing rather than guessing. Household units: rice
in grams with cooked and raw, ml only for liquids, no katori or sabzi. No em dashes, no emoji, no vague hero lines.

## 7. Banned

Purple gradients, fake reviews or counters, stock or AI photos, emoji icons, cursor effects, heavy scroll animation,
and any metric the app does not measure.

## 8. Accessibility

48 dp touch targets, text scaling to 1.5, 4.5:1 text contrast, labels on inputs, screen-reader labels on icon buttons,
errors with icon and text. Check at 320 and 390 dp, light and dark.

## 9. Review status

Seen in the 2026-11-07 redesign, on a real Android phone (debug test build, local test account): sign-in, permissions, Today,
Workout, session, Diet, Progress, More, Handbook list, Protocol, exercise library, Habits, Profile, Settings, dark mode. On web
only: a book chapter and its link, coach, Calendar, food diary, Water. **Not reviewed:** later onboarding steps, Build my plate.
