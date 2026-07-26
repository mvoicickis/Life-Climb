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

## Colour

| Role | Token / hex | Use |
|------|-------------|-----|
| Primary | `--lp-forest` `#166534` | Buttons, links, progress bar, logo mark |
| Dark background | `--lp-navy` `#0B1220` | Landing hero + closing; calm “mountain at dusk” |
| Light background | `--lp-paper` `#F5F6F3` | Content sections + daily reading surfaces |
| Reward accent | `--lp-gold` `#E0A82E` | **Only** LP numbers, `+LP` pop-ups, reward moments |

Gold appears only when the user earns something. If gold is everywhere, it stops feeling special.

### Legacy game-surface tokens (in-app)

Existing Home / Journey / Progress screens may still use Neon Mountain tokens (`--lp-void`, `--lp-neon`, etc.). New marketing and onboarding should follow navy + forest + paper above. Align remaining app chrome to this brand over time.

| Token | Hex | Role |
|-------|-----|------|
| `--lp-void` | `#070B09` | Legacy dark app shell |
| `--lp-surface` | `#0E1612` | Legacy panels |
| `--lp-elevated` | `#15201A` | Legacy elevated glass |
| `--lp-emerald` | `#10B981` | Legacy healthy / secondary |
| `--lp-neon` | `#84F23A` | Legacy Home neon mark |
| `--lp-gold` | `#E8C468` / `#E0A82E` | Rewards only |
| `--lp-ink` | `#F3F7F4` | Text on dark |
| `--lp-muted` | `#8FA399` | Secondary on dark |

## Typography

- **Display (serif):** Fraunces — big headlines, mountain / journey names (story weight).
- **UI (sans):** Source Sans 3 — body and buttons.
- Keep only these two fonts across landing and app. More fonts = less trust.

## Icons & imagery

- Thin, single-line icons for steps and UI (not filled, not photo-realistic).
- Emoji allowed **only** for Life Areas (consistent with in-app catalog).
- No stock photos of people.
- Mountain line-art silhouettes everywhere the metaphor appears: landing, onboarding, Journey.

## App consistency (direction)

- **Onboarding:** same navy + forest + mountain-line style as the landing hero.
- **Home:** prefer paper/light reading surfaces; gold only when LP is earned.
- **Life Tree:** brand green as growth reward after a win.
- **Journey:** same mountain-line illustration language as the landing hero.

## Legacy components (game surfaces)

| Component | Spec |
|-----------|------|
| `GlassCard` | `rounded-3xl`, glass bg, soft border |
| `GapMeter` | Track + forest/green fill |
| `PrimaryCTA` | Forest green, light label on dark / white label on forest |
| `BottomNav` | Dashboard · Life Map · + FAB · Missions · Profile |

## Motion

- Landing: brand fade-in, mountain drift, CTA pulse, LP count-up (gold).
- Respect `prefers-reduced-motion`.
- In-app: `+LP` float, soft progress ease — no spam confetti.

## Hard product rules (UI)

- **No streaks.** Closer % and next step drive emotion — never flame counters.
- **Copy tone:** warm, meaning-first; gap = distance to the mountain, not guilt.
