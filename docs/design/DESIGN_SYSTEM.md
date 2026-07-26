# LifePoints Brand & Design System

## Brand idea

LifePoints helps a person turn any life goal into a real plan, and rewards real progress with Life Points — proof that they are becoming more alive.

## Voice

- Short sentences. Never explain with a long paragraph what one short line can say.
- Human, not corporate. Say “Pick your mountain,” not “Select your primary objective.”
- Show, don’t list. One real example (“Run for 15 minutes”) beats five abstract words.
- No fake urgency. Never use countdown timers, scarcity copy, or streak-shame language.

**Use often:** mountain · climb · battle · plan · alive · closer  

**Avoid:** streak · habit · tracker · productivity · grind · hustle  

## Colour (app-wide)

| Role | Token / hex | Use |
|------|-------------|-----|
| Primary | `--lp-forest` `#166534` | Buttons, links, progress bars, brand mark |
| Dark background | `--lp-navy` `#0B1220` | Landing hero/closing, auth, onboarding (`.lp-game--navy`) |
| Light background | `--lp-paper` `#F5F6F3` | Home, Journey, Progress daily surfaces (`.lp-game`) |
| Reward accent | `--lp-gold` `#E0A82E` | **Only** LP numbers, `+LP` pop-ups, reward moments |

Gold appears only when the user earns something. If gold is everywhere, it stops feeling special.

Legacy aliases (`--lp-neon`, `--lp-void`, `--lp-lime`, `--lp-emerald`) resolve to forest / navy so older class names stay on-brand.

## Typography

- **Display (serif):** Fraunces — big headlines, mountain / journey names.
- **UI (sans):** Source Sans 3 — body and buttons.
- Keep only these two fonts across landing and app.

## Icons & imagery

- Thin, single-line icons for steps and UI.
- Emoji allowed **only** for Life Areas (consistent with in-app catalog).
- No stock photos of people.
- Mountain line-art silhouettes on landing, Home hero, and Journey.

## Surface map

| Surface | Shell |
|---------|--------|
| Landing | `.lp-landing-body` — navy hero/closing, paper mid sections |
| Auth | navy body + forest CTAs |
| Onboarding | `.lp-game.lp-game--navy` |
| Home / Journey / Progress | `.lp-game` paper + white cards |
| Studio (legacy) | paper + forest accent |

## Hard product rules (UI)

- **No streaks.** Closer % and next step drive emotion — never flame counters.
- **Copy tone:** warm, meaning-first; gap = distance to the mountain, not guilt.
- **Motion:** brand fade, mountain drift, CTA pulse, gold LP count-up; respect `prefers-reduced-motion`.
