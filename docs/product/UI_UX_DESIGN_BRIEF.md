# Levlofit: UI/UX Design Brief

Last updated: 2026-11-07, for release 1.0.10. Keep current: see "Keeping these documents current" in `CLAUDE.md`.
Tokens and logo rules in full: `DESIGN.md`. Code: `app/lib/theme.dart`.

## 1. Direction

Soft, calm, rounded, easy to scan: white cards on soft grey, one floating bar, one accent. Premium and trustworthy for
Indian users, and never looking AI-made. Owner chose this look on 2026-11-07 from reference images; it was rebuilt in
Levlofit's own form and data, not copied.

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

Geist everywhere in the app; numbers with tabular figures. Unbounded for the wordmark only. Noto Serif for long Handbook
reading. Headings 22 to 30 px bold, body 15 to 16, captions 13, small uppercase labels 12 with light tracking. 12 px minimum.

## 4. Shape and motion

- Cards 28 px radius, hairline border, no heavy shadow. Pills for buttons and chips; inputs 18 px.
- One soft fade, charcoal into the page, behind the AI coach header only. No other gradients.
- Motion: gentle rise and fade, numbers count up, arcs draw in. Off under reduced motion.

## 5. Components

| Component | Rule |
|---|---|
| Floating bar | Charcoal pill; current tab a white pill with an orange icon and its name; others round icons with tooltips |
| Activity card | Grey panel with two arcs, white stats panel beside it |
| Tiles | Label, big number, short caption; half-width tiles pair up |
| Plate meal card | Plate picture, name and time, kcal and protein, servings; tap for grams; Swap and Ate it |
| Info card | Label plus short lines: training day, supplements |
| Coach | Your messages in charcoal, replies on white cards, pill composer |
| Dark panels | Water, Habits, Progress verdict: charcoal, light text |

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

Seen in the new look: Home, plate cards, coach, Workout, session, Progress, Water, Habits, Settings, sign-in, first
onboarding step. **Not reviewed:** later onboarding steps, Build my plate, side menu, food diary, Handbook, exercise
library, Calendar. **Nothing on a real phone yet.**
