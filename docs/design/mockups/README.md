> **Archive — not current product specification**
>
> This document is an archive of historical design concepts.
> It is **not** the current product specification.
>
> - Current UI documentation: [`docs/ui_design.md`](../../ui_design.md)
> - Current product vision: [`docs/vision.md`](../../vision.md)

# LifePoints mockups index

High-fidelity concepts for the Close-the-Gap redesign. Visual system: [`DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md).

**Canonical Home** (locked board): `02-home-dashboard.png`  
**Character:** onboarding `01`, map Man `03`, map Woman `03b`, profile `14`, settings `15`

| File | Screen | Batch |
|------|--------|-------|
| `01-character-select.png` | Onboarding — Choose companion | A |
| `02-home-dashboard.png` | Home / Dashboard (canonical) | A |
| `03-life-map.png` | Life Map (Man center) | A |
| `03b-life-map-woman.png` | Life Map (Woman center) | A |
| `04-area-detail.png` | Life Area detail | A |
| `05-gap-comparison.png` | Ideal vs Present / Gap | A |
| `06-daily-mission.png` | Daily Mission (no streaks) | A |
| `07-mission-complete.png` | Mission celebration | A |
| `08-level-up.png` | Level Up | A |
| `09-tree-of-life.png` | Tree of Life progress | A |
| `22-area-progress-stack.png` | Multi-area progress meters | A |
| `10-dream-wizard.png` | Dream creation wizard | B |
| `12-planning.png` | Planning | B |
| `13-achievements.png` | Achievements | B |
| `14-profile.png` | Profile | B |
| `15-settings.png` | Settings (change character) | B |
| `16-pricing.png` | Pricing | B |
| `11-landing-desktop.png` | Landing desktop | C |
| `21-landing-mobile.png` | Landing mobile | C |
| `17-community.png` | Community | C |
| `18-statistics.png` | Statistics | C |
| `19-weekly-review.png` | Weekly review | C |
| `20-year-review.png` | Year review | C |

Companion PNG assets live in [`app/assets/images/characters/`](../../app/assets/images/characters/) (`birdie`, `bee`, `bear`, `fox`, `horse`, `raven`).

Production partials (wire later): `_character_picker`, `_lp_bottom_nav`.

## Historical Context

These mockups influenced LifePoints’ direction: the mountain metaphor, Ideal vs Present gap, character identity, and celebration moments.

The shipped product has since diverged in places. Navigation is now **Mountain · Today · Journey · You** (not Life Map–first). Hierarchy is **Goal → Plan → Project → Battle** on Strategy, with Mountain Focus as the climb UI. Visual chrome on Mountain is a dark RPG scenic climb rather than the light Home dashboard shown as “canonical” above.

Treat this folder as design history and inspiration. Do not implement screens from this index as if they were the current spec.
