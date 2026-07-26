# LifePoints Brand & Design System

## Brand idea

LifePoints helps a person turn any life goal into a real plan, and rewards real progress with Life Points — proof that they are becoming more alive.

Feeling: **small steps, big life** — one mountain, today’s battle. Hope + invitation on a clean light shell, with Life Green as the action color.

## Voice

- Short sentences. Never explain with a long paragraph what one short line can say.
- Human, not corporate. Say “Pick your mountain,” not “Select your primary objective.”
- Show, don’t list. One real example (“Run for 15 minutes”) beats five abstract words.
- No fake urgency. Never use countdown timers, scarcity copy, or streak-shame language.

**Use often:** mountain · climb · battle · plan · alive · closer  

**Avoid:** streak · habit · tracker · productivity · grind · hustle  

## Colour — Life Green (app-wide)

| Role | Token / hex | Use |
|------|-------------|-----|
| Page / app bg | `--lp-paper` `#FFFFFF` | Landing, Home, Journey, Progress, auth |
| Soft band / mist | `--lp-mist` `#F1F5F9` | Alternating sections, tracks, soft chips |
| Ink | `--lp-ink` `#0F172A` | Body, titles, **LP numbers**, closer % |
| Charcoal | `--lp-charcoal` `#334155` | Secondary headings |
| Muted / slate | `--lp-muted` `#64748B` | Supporting lines |
| Primary / CTA | `--lp-green` `#22C55E` | Buttons, links, progress fills |
| Primary deep | `--lp-green-deep` `#16A34A` | Hover / Emerald |
| Soft green | `--lp-green-soft` `#86EFAC` | Light washes, soft fills |
| Dawn wash | `#ECFDF5 → #FFFFFF` | Landing hero / closing atmosphere |
| Reward flash only | `--lp-gold` `#F59E0B` | `+LP` toast / confetti only |

**Hard readability rule:** LP chip and standing LP totals use deep ink on white/mist chips. Amber/gold is never the digit color.

Legacy aliases (`--lp-teal`, `--lp-forest`, `--lp-neon`, `--lp-emerald`) resolve to Life Green so older class names stay on-brand.

Life-area accents (Love, Growth, Mind, Health, Wealth, Home) are for category marks only — not page chrome.

## Typography

- **Display (serif):** Fraunces — big headlines, mountain / journey names.
- **UI (sans):** Source Sans 3 — body and buttons.
- Keep only these two fonts across landing and app.

## Icons & imagery

- Thin, single-line icons for steps and UI.
- Emoji allowed **only** for Life Areas (and Home hero area mark).
- No stock photos of people.
- Mountain path + summit flag art in Life Green / soft green on light paper heroes.

## Surface map

| Surface | Shell |
|---------|--------|
| Landing | Soft green dawn hero/closing + white/mist mid sections |
| Auth | Light dawn paper + Life Green CTAs |
| Onboarding | `.lp-game` paper (same as Home) |
| Home / Journey / Progress | `.lp-game` paper + white cards |

## Hard product rules (UI)

- **No streaks.** Closer % and next step drive emotion.
- **Copy tone:** warm, meaning-first; gap = distance to the mountain, not guilt.
- **Motion:** brand fade, mountain drift, CTA pulse, amber only on `+LP` flash; respect `prefers-reduced-motion`.
