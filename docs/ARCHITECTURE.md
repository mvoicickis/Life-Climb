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
- **Next win** (Milestone language) is a multi-day destination on the Journey — never called Project.
- **Statistics are never configured in planning.** They may emerge later from typed mission templates, not free-text magic.
- Rails conventions first; one feature at a time; MVP before optimization.
- Decision filter: closer to Ideal Scene? reduces complexity? improves motivation?

## Domain ownership

```text
Life Area  →  Life Journey (+ next_win)  →  Daily Mission
```

Users feel: Area · Journey · Next win · Today. Hierarchy is invisible on Home.

## Coach planning (want → now → next → today)

1. Pick one Life Area
2. What do you want? → Journey Ideal / title
3. Where are you now? → Present
4. What's the next big win? → `life_journeys.next_win`
5. What can you finish in one sitting? → today's Mission title
6. Home shows that Mission + Done

No blocker question required. No Project/Plan models. No stats wizard.

## One mountain at a time

- Onboarding picks **exactly one** Life Area, then the four coach beats.
- Default Focus is **one** Journey (set automatically).
- Completing a Journey is **user-declared** → LP + next mountain (same Area or new Area).
- Areas accumulate over years; Journeys come and go.

## MVP schema (lean)

Persisted now: `users` (+ `planning_version`), selected `life_areas`, `life_journeys` (Ideal/Present/`next_win`), Focus via `focus_position`, `missions`, LP ledger, `gap_snapshots`.

**Not** in MVP: Plan/Program/Project/Purpose/Policy/Statistic/WeeklyReview/tree_progress tables, IdealScene 1:1 tables, generate-on-GET, habit LP for `planning_version = 2`, Focus/Life Map on the planning happy path.

## Strangler

- `planning_version = 1` — legacy Dream → Goal → Building → TodayAction
- `planning_version = 2` — Area → Journey → Mission loop; sole LP writer is the mission award path

## Extension points (post-MVP)

- Thin `milestones` table if multiple open next-wins need history (still labeled Milestone / next win in UI)
- Mission templates / tags → emergent statistics (never a planning form)
- Gap/LP services remain the only writers of those invariants

See also: design system under `docs/design/`.
