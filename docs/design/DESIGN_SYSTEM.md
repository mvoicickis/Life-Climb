# LifePoints Game Design System

Locked visual language for the Close-the-Gap redesign. Use these tokens for all new game surfaces. Do not revert new screens to light `--studio-paper`.

## Colour

| Token | Hex | Role |
|-------|-----|------|
| `--lp-void` | `#070B09` | App background |
| `--lp-surface` | `#0E1612` | Base panels |
| `--lp-elevated` | `#15201A` | Cards / elevated glass base |
| `--lp-glass` | `rgba(21, 32, 26, 0.72)` | Frosted cards |
| `--lp-border` | `rgba(16, 185, 129, 0.2)` | Card borders |
| `--lp-emerald` | `#10B981` | Primary actions / healthy |
| `--lp-lime` | `#A3E635` | Neon energy / avatar ring (Home mockup) |
| `--lp-mint` | `#34D399` | Secondary glow |
| `--lp-gold` | `#E8C468` | XP, trophies, legendary |
| `--lp-rose` | `#FB7185` | Far gap / neglect |
| `--lp-ink` | `#F3F7F4` | Primary text |
| `--lp-muted` | `#8FA399` | Secondary text |
| `--lp-track` | `#27272A` | Meter recess (`zinc-800`) |

## Typography

- **Display / game titles:** Fraunces or Sora — bold, tight tracking for “TODAY’S MISSION”, “LEVEL UP”
- **UI body:** Source Sans 3 / Manrope — medium weight, readable on dark
- **Labels:** 11–12px uppercase, wide tracking, lime/teal muted

## Components

| Component | Spec |
|-----------|------|
| `GlassCard` | `rounded-3xl`, glass bg, `border` emerald/20, soft shadow |
| `GapMeter` | `h-3` track zinc-800, fill lime→teal gradient, optional markers |
| `MissionCard` | Photo backdrop, LP + Morale chips, pill CTA |
| `AreaNode` | Circle icon + % label; selected = scale + glow ring |
| `PlayerAvatar` | Circular Man/Woman art, lime glow ring |
| `CharacterPicker` | Two large portrait cards |
| `PrimaryCTA` | Full-width or pill, teal/lime gradient, dark label |
| `BottomNav` | Dashboard · Life Map · + FAB · Missions · Profile |
| `RewardToast` / `LevelUpModal` | Gold particles, centered glass card |

## Motion

- Mission done: gap ease, `+LP` float, energy pulse
- Level up: gold wash + soft particles (no spam confetti storms)
- Map nodes: gentle breathe; neglected desaturate
- Transitions: fade + slight scale

## Character (v1)

`man` | `woman` — illustrated portraits only. Used on Home header, Life Map center/path, Profile. Changeable in Settings.

## Life Map nodes (8)

Self · Love · Family · Community · Humanity · Animals · Nature · Home  

Stages: Seed → Plant → Tree → Forest → Legendary  

## Screens inventory

See mockups in `docs/design/mockups/` and `docs/design/RAILS_IMPLEMENTATION.md`.
