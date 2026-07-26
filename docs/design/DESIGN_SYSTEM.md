# LifePoints Brand & Design System

## Canonical visual guide

Use this board as the source of truth for colour, type, mountain art, and UI chrome:

- [`docs/design/BRAND_GUIDE_LIFE_GREEN.jpg`](BRAND_GUIDE_LIFE_GREEN.jpg) (also `.webp`)

**Note:** that board still shows the retired leaf sprout in places — treat it as historical for colour/type only. The **mountain circle mark** is law for product UI.

Landing hero / scene assets live in `public/branding/`.

## Brand idea

LifePoints helps a person pick one mountain, build the climb on **Strategy** (goal → plans → projects → battles), fight on **Today** for **Action Points**, and reflect on **Journey**. Finished **projects** move mountain percent — battles win the day, not the year. Strategy Points reward planning. Proof you are becoming more alive.

Feeling: **One mountain. Today’s battle.** Hope + invitation on a clean light shell, with Life Green as the action color.

Legacy lockup tagline “SMALL STEPS. BIG LIFE.” remains on some PNG assets — prefer the live slogan for new marketing lockups; do not regenerate bitmaps unless intentionally redesigning.

## Voice

- Short sentences. Never explain with a long paragraph what one short line can say.
- Human, not corporate. Say “Pick your mountain,” not “Select your primary objective.”
- Show, don’t list. One real example (“Run for 15 minutes”) beats five abstract words.
- No fake urgency. Never use countdown timers, scarcity copy, or streak-shame language.

**Use often:** mountain · climb · battle · plan · project · expedition · Action Points · Strategy Points · alive · closer  

**Avoid:** streak · habit · tracker · productivity · grind · hustle · bare “LP” in player chrome (say Action Points / AP)

## Colour — Life Green (app-wide)

| Role | Token / hex | Use |
|------|-------------|-----|
| Page / app bg | `--lp-paper` `#FFFFFF` | Landing, Home, Journey, auth |
| Soft band / mist | `--lp-mist` `#F1F5F9` | Alternating sections, tracks, soft chips |
| Ink | `--lp-ink` `#0F172A` | Body, titles, **Action Points numbers**, mountain % |
| Charcoal | `--lp-charcoal` `#334155` | Secondary headings |
| Muted / slate | `--lp-muted` `#64748B` | Supporting lines |
| Primary / CTA | `--lp-green` `#22C55E` | Buttons, links, progress fills |
| Primary deep | `--lp-green-deep` `#16A34A` | Hover / Emerald |
| Soft green | `--lp-green-soft` `#86EFAC` | Light washes, soft fills |
| Dawn wash | `#ECFDF5 → #FFFFFF` | Landing hero veil / closing atmosphere |
| Reward flash only | `--lp-gold` `#F59E0B` | `+AP` toast / confetti only |

**Hard readability rule:** Action Points chips and standing totals use deep ink on white/mist chips. Amber/gold is never the digit color.

Legacy aliases (`--lp-teal`, `--lp-forest`, `--lp-neon`, `--lp-emerald`) resolve to Life Green so older class names stay on-brand.

Life-area accents (Love, Growth, Mind, Health, Wealth, Home) are for category marks only — not page chrome.

## Typography

- **Display (serif):** Fraunces — big headlines, mountain / journey names.
- **UI (sans):** Source Sans 3 — body and buttons.
- Keep only these two fonts across landing and app.

## Icons & imagery

- Canonical logo (lockup): `public/branding/lifepoints-logo.png` — mountain circle + LifePoints wordmark (PNG still carries “SMALL STEPS. BIG LIFE.”; prefer **One mountain. Today’s battle.** for new lockups)
- Canonical mark (icon crop): `public/branding/lifepoints-mark.png` — circular mountain mark for favicon, app icon, BMC avatar, nav (soft expedition badge; keep — do not swap for battle iconography in this era)
- App icon: `public/icon.png` (from the mark)
- **Canonical share / OG only:** `public/og-lifepoints-logo.png` (1200×630). Orphan files `og-lifepoints.png`, `og-lifepoints-neon.png`, `og-share.png` are legacy — do not wire into meta tags
- Landing hero: mountain path + summit flag (`public/branding/landing-hero-mountain.webp`)
- Thin, single-line icons for steps and UI.
- Emoji allowed **only** for Life Areas (and Home hero area mark).
- No stock photos of people.
- Full-bleed mountain path art on light paper heroes — never a navy void marketing shell.
- Retired: leaf sprout mark (`lifepoints-leaf-mark.png`) — do not use for new UI.

## Surface map

| Surface | Shell |
|---------|--------|
| Landing | Soft green dawn hero/closing + white/mist mid sections |
| Auth | Light dawn paper + Life Green CTAs |
| Onboarding | `.lp-game` paper (same as Home) |
| Today / Strategy / Journey / You | `.lp-game` paper + white cards |

## Hard product rules (UI)

- **No streaks.** Mountain % and next step drive emotion.
- **One mountain %** everywhere (Today = Strategy = Journey) — project-gated; battles do not move year %.
- **Copy tone:** warm, meaning-first; gap = distance to the mountain, not guilt.
- **Motion:** brand fade, mountain drift, CTA pulse, amber only on `+AP` flash; respect `prefers-reduced-motion`.
