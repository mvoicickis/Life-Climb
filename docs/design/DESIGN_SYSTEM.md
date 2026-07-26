# LifePoints Brand & Design System

## Brand idea

LifePoints helps a person turn any life goal into a real plan, and rewards real progress with Life Points — proof that they are becoming more alive.

Feeling: **nothing is impossible** — and this app will help if you give it a chance. Hope + invitation, not night-game intensity.

## Voice

- Short sentences. Never explain with a long paragraph what one short line can say.
- Human, not corporate. Say “Pick your mountain,” not “Select your primary objective.”
- Show, don’t list. One real example (“Run for 15 minutes”) beats five abstract words.
- No fake urgency. Never use countdown timers, scarcity copy, or streak-shame language.

**Use often:** mountain · climb · battle · plan · alive · closer  

**Avoid:** streak · habit · tracker · productivity · grind · hustle  

## Colour — Clear Day (app-wide)

| Role | Token / hex | Use |
|------|-------------|-----|
| Page / app bg | `--lp-paper` `#FAFBFA` | Landing, Home, Journey, Progress, auth |
| Soft band | `--lp-paper-soft` `#F0F4F2` | Alternating sections |
| Ink | `--lp-ink` `#121816` | Body, titles, **LP numbers**, closer % |
| Muted | `--lp-muted` `#5C6B64` | Supporting lines |
| Primary / CTA | `--lp-teal` `#0F766E` | Buttons, links, progress fills |
| Primary deep | `--lp-teal-deep` `#0D5F59` | Hover |
| Dawn wash | `#E8F4F1 → #FAFBFA` | Landing hero / closing atmosphere |
| Reward flash only | `--lp-gold` `#D4A017` | `+LP` toast / confetti only |

**Hard readability rule:** LP chip and standing LP totals use deep ink on white/soft chips. Gold is never the digit color.

Legacy aliases (`--lp-forest`, `--lp-neon`, `--lp-emerald`) resolve to teal so older class names stay on-brand.

## Typography

- **Display (serif):** Fraunces — big headlines, mountain / journey names.
- **UI (sans):** Source Sans 3 — body and buttons.
- Keep only these two fonts across landing and app.

## Icons & imagery

- Thin, single-line icons for steps and UI.
- Emoji allowed **only** for Life Areas (and Home hero area mark).
- No stock photos of people.
- Mountain line-art in muted teal on light dawn heroes.

## Surface map

| Surface | Shell |
|---------|--------|
| Landing | Dawn light hero/closing + paper mid sections |
| Auth | Light dawn paper + teal CTAs |
| Onboarding | `.lp-game` paper (same as Home) |
| Home / Journey / Progress | `.lp-game` paper + white cards |

## Hard product rules (UI)

- **No streaks.** Closer % and next step drive emotion.
- **Copy tone:** warm, meaning-first; gap = distance to the mountain, not guilt.
- **Motion:** brand fade, mountain drift, CTA pulse, gold only on `+LP` flash; respect `prefers-reduced-motion`.
