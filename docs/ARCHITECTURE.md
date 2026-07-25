# LifePoints Architecture (source of truth)

LifePoints is a **Life Operating System**, not a habit tracker. It helps people close the gap between **Current Reality** and **Ideal Scene**.

## UX first (highest priority)

Ease and motivation beat clever architecture.

- A new user should always know: what I'm working on, what to do today, whether I'm progressing.
- Prefer one clear CTA. Prefer plain language. Prefer automation over forms.
- If a screen needs explaining, simplify the screen.
- Coach voice: one question, one answer, one CTA. Never expose Plans or Projects.

## Product rules (locked)

- Dashboard answers only: What am I working on? What should I do today? Am I making progress?
- Complexity stays inside the system.
- **One mountain** Focus by default (Focus UI is not on the happy path).
- **Daily Missions** are one-sitting actions; Life Points come from completing missions.
- **Milestone** (`next_win`) is optional multi-day step — never called Project.
- **Statistics are never configured in planning.**
- Rails conventions first; one feature at a time; MVP before optimization.

## Domain ownership

```text
Life Area  →  Life Journey (+ optional next_win)  →  Daily Mission
```

## MVP coach flow

1. Focus — which area first? (exactly one)
2. Journey — what do you want to achieve? → `title`
3. Vision — what does success look like? → `ideal_scene`
4. Reality — where are you today? → `current_reality`
5. Progress — how close? (default 5%) → `gap_percent = 100 - closer`
6. Milestone — next major step? (**optional**) → `next_win`
7. Mission — one thing today → Mission title
8. Dashboard — Area · Journey · Today’s Mission · Progress % · Life Tree

No Project/Plan models. No stats wizard.

## One mountain at a time

- Onboarding picks **exactly one** Life Area, then the coach beats above.
- Default Focus is **one** Journey (set automatically).
- Completing a Journey is **user-declared** → LP + next mountain (same Area or new Area).

## MVP schema (lean)

Persisted now: `users` (+ `planning_version`), selected `life_areas`, `life_journeys` (Ideal/Present/`next_win`), Focus via `focus_position`, `missions`, LP ledger, `gap_snapshots`.

**Not** in MVP: Plan/Program/Project/Purpose/Policy/Statistic tables, generate-on-GET, habit LP for `planning_version = 2`.

## Strangler

- `planning_version = 1` — legacy Dream → Goal → Building → TodayAction
- `planning_version = 2` — Area → Journey → Mission loop; sole LP writer is the mission award path

See also: design system under `docs/design/`.
