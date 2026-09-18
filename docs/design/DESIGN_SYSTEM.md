# Life Climb — Design System

**Token source:** [`app/assets/tailwind/application.css`](../../app/assets/tailwind/application.css) `:root` (lines 3281–3386). Use CSS variables only — do not hardcode hex in new UI.

## Brand feel

Light mode only. Clean, calm, Apple-like: soft page wash, white cards, generous spacing, one green accent. **One mountain. Today’s battle.**

Product chrome (Home, Strategy, Journey, You, Settings, sheets, forms) stays on the light palette. **Exception:** the marketing landing page (`.lp-landing-body`) uses a dark cinematic shell — not a user theme toggle.

Assets: `public/branding/` (logo, mark, hero). Mountain circle mark is canonical for product UI. Retired leaf sprout — do not use.

## Voice

Short, human copy. No fake urgency, streak-shame, or “productivity” jargon. Say Action Points / AP in player chrome, not bare “LP”.

## Colour (app chrome)

| Role | Token | Value |
|------|--------|--------|
| Page background | `--lp-paper` | `#f8fafc` |
| Soft bands | `--lp-paper-soft` | `#eef2f7` |
| Tracks / mist | `--lp-mist` | `#e2e8f0` |
| Cards / elevated | `--lp-surface`, `--lp-elevated` | `#ffffff` |
| Primary text | `--lp-ink` | `#0f172a` |
| Secondary headings | `--lp-charcoal` | `#334155` |
| Muted text | `--lp-muted` | `#475569` |
| Borders | `--lp-border` | `rgba(15, 23, 42, 0.1)` |
| Primary accent | `--lp-green` | `#57d35b` |
| Accent hover / pressed | `--lp-green-deep` | `#3dbd48` |
| Soft green wash | `--lp-green-soft` | `rgba(87, 211, 91, 0.28)` |
| Destructive actions only | `--rpg-red` | `#ef4444` |
| Reward flash only | `--lp-gold` | `#d4a017` |

**CTA note:** `.lp-cta` still backgrounds with `--lp-teal` (`#3ec9c0`). New work should use `--lp-green` / `--lp-green-deep`; aligning `.lp-cta` is a follow-up PR.

**Mountain overlay:** HUD chips and labels on trail art may use `--lp-rpg-*` frosted glass (light tints in `:root`) for contrast on scenery — not dark modals.

Life-area accent colours are for category marks only, not page chrome.

## Typography

- **Family:** `--lp-font-ui` / `--lp-font-display` — Nunito, system-ui fallback.
- **Display headlines:** `--lp-type-display-lg` / `-md` / `-sm` (fluid clamp) — weight **700–900**, tight letter-spacing on large titles.
- **Body & UI:** `--lp-type-ui-lg` / `-md` / `-sm` — weight **400–700** for copy and labels.
- **Buttons:** weight **800**, pill shape (`--lp-radius-pill`).
- **Small labels / kickers:** ~`0.68rem`, weight **800**, uppercase, wide letter-spacing.

## Layout, radius, shadow

- **Spacing:** `--lp-space-1` … `--lp-space-4`; card padding `--lp-pad-card`.
- **Tap targets:** min `--lp-tap` (2.75rem).
- **Cards:** `--lp-radius-card` (1.25rem), `--lp-shadow-card`.
- **Fields:** `--lp-radius-field` (0.85rem).
- **Primary buttons:** `--lp-radius-pill`, `--lp-shadow-cta` on green CTAs (onboarding uses `--lp-green`).

Prefer whitespace over dense stacks. Long labels wrap; design for **360px** width first.

## Surfaces

| Surface | Shell |
|---------|--------|
| App (`.lp-game`) | `--lp-paper` + white `--lp-surface` cards |
| Onboarding | Same light shell as app |
| Auth | Light paper + green CTAs |
| Landing | Dark exception (scoped tokens on `.lp-landing-body`) |

No dark mode in product settings. Do not add dark sheets, dark settings panels, or `prefers-color-scheme` chrome.

## Product rules (UI)

- No streak UI; mountain % and next step carry progress emotion.
- One mountain % across Today / Strategy / Journey (project-gated).
- AP totals: ink on white/mist chips; gold only for `+AP` celebration, not standing digits.
- Respect `prefers-reduced-motion` for motion.

## Related docs

- Engineering map: [`RAILS_IMPLEMENTATION.md`](RAILS_IMPLEMENTATION.md)
- HTML mockups: [`mockups/README.md`](mockups/README.md)
