# Rails implementation map (follow-up)

Engineering plan to rebuild LifePoints Hotwire/Tailwind UI against the locked design boards and mockups in `docs/design/`.

## Phase 0 — Foundations

1. Apply `.lp-game` shell on authenticated app layout (or Today-first), keep legacy studio theme only on unmigrated pages.
2. CSS tokens already in [`app/assets/tailwind/application.css`](../../app/assets/tailwind/application.css) (`--lp-*`). Utilities: `.lp-glass`, `.lp-cta`, `.lp-avatar-ring`, `.lp-gap-track` / `.lp-gap-fill`, `.lp-bottom-nav`, `.lp-fab`.
3. Add `users.character` string: one of `birdie` | `bee` | `bear` | `fox` | `horse` | `raven` (nullable until onboarding; legacy `man`/`woman` do not count as chosen).
4. Serve companions from `app/assets/images/characters/{birdie,bee,bear,fox,horse,raven}.png`.
5. Mount design partials: [`_character_picker`](../../app/views/shared/_character_picker.html.erb), [`_lp_bottom_nav`](../../app/views/shared/_lp_bottom_nav.html.erb).
6. **Do not ship streak UI** — omit flame counters; use Overall Gap + Morale only.

## Phase 1 — Character + Home HUD

| UI | Rails |
|----|--------|
| Character picker | Onboarding step or `settings#update` |
| Home greeting + avatar | [`dashboard/show`](../../app/views/dashboard/show.html.erb) partials |
| LP hero | `user.life_points` + ledger sum today |
| Overall Gap % | Derive from life areas: average of `(100 - closer_percent)` or inverse of mean closer |
| Life Map ring | `dream.life_areas` — expand keys to 8 (add `family`, `nature` or remap) |
| Today’s Mission | Focus `today_actions` incomplete first |
| Morale | New lightweight field or compute from recent completions (v1: simple score 0–100) |
| Bottom nav + FAB | Replace studio tabbar |

## Phase 2 — Map / Area / Gap / Mission

| Screen | Approach |
|--------|----------|
| Life Map full | New `life_map#show` or dashboard mode |
| Area detail | Enhance [`life_areas/show`](../../app/views/life_areas/show.html.erb) with Dream/Current/Gap/Mission CTA |
| Gap | Same area with emphasis meter (`closer_percent` / gap) |
| Mission | Dedicated mission show around `TodayAction` |
| Complete / Level up | Turbo Stream overlays + AliveLevel |

## Phase 3 — Planning + rewards

- Obstacle / why / strategy: new text fields on `life_areas` or `goals`
- Plan = Building + steps (existing)
- Achievements: new model later; start with static unlock flags on user JSON
- Treasure / Finished Products = existing finished shelf restyled

## Phase 4 — Marketing + social

- Landing: rebuild [`pages/home`](../../app/views/pages) to match desktop/mobile mockups
- Pricing / community / weekly-year review: new controllers after core loop ships

## Data notes

- Prefer extending `LifeArea` over a parallel GoalProgress table.
- Gap display = `100 - closer_percent` when product copy says “away from dream”; keep `closer_percent` as progress toward Ideal.
- Do not hardcode percents in views — always model methods.

## Suggested ship order

1. Tokens + dark shell on Today  
2. Character column + picker  
3. Home dashboard layout matching `02-home-dashboard.png`  
4. Area + mission game chrome  
5. Landing  
6. Achievements / reviews  

## Out of scope for first eng sprint

- Full 8-area migration data backfill automation  
- Real-time multiplayer community  
- Native sound pack (mute toggle stub OK)  
