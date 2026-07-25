# LifePoints Architecture (source of truth)

LifePoints is a **Life Operating System**, not a habit tracker. It helps people close the gap between **Current Reality** and **Ideal Scene**.

## UX first (highest priority)

Ease and motivation beat clever architecture.

- A new user should always know: what I'm working on, what to do today, whether I'm progressing.
- Prefer one clear CTA. Prefer plain language. Prefer automation over forms.
- If a screen needs explaining, simplify the screen.

## Product rules (locked)

- Dashboard answers only: What am I working on? What should I do today? Am I making progress?
- Complexity stays inside the system.
- **Focus** ≤ 3 Life Journeys; changing focus never deletes progress.
- **Daily Missions** are the core gameplay loop; Life Points come from completing missions.
- Rails conventions first; one feature at a time; MVP before optimization.
- Decision filter: closer to Ideal Scene? reduces complexity? improves motivation?

## Domain ownership

```text
Life Area  →  Life Journey  →  Daily Mission
```

**Each Life Journey owns its own world** (not a global Ideal/Present/Gap):

- `ideal_scene` / `current_reality` — columns on the journey
- `gap_percent` + `gap_snapshots` — per journey
- `missions` — belong to the journey
- Progress is journey-scoped; User LP/Level stay player-wide

Life Area is the permanent category and **tree branch**. Branch vitality is **derived** from that area’s focused or latest active Journey gap (no extra tables).

Home shows the **primary Focus** journey’s gap (e.g. “Career gap”), not “overall life.” A quiet attention line may point at another focused journey with a worse gap.

User-facing MVP naming uses **Life Journey** (not Dream/Goal rename).

## MVP schema (lean)

Persisted now: `users` (+ `planning_version`), selected `life_areas`, `life_journeys` (Ideal/Present columns), Focus via `focus_position`, `missions`, LP ledger, `gap_snapshots`.

**Not** in MVP: Plan/Program/Project/Purpose/Policy/Statistic/WeeklyReview/tree_progress tables, IdealScene 1:1 tables, generate-on-GET, habit LP for `planning_version = 2`.

## Strangler

- `planning_version = 1` — legacy Dream → Goal → Building → TodayAction
- `planning_version = 2` — Area → Journey → Mission loop; sole LP writer is the mission award path

## Extension points (post-MVP)

- `Missions::EnsureDaily` may later prefer a Project step
- Gap/LP services remain the only writers of those invariants
- Planning spine tables added when a generator writes rows

See also: design system under `docs/design/`.
