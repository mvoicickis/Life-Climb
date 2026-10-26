# LifePoints Architecture (legacy product notes)

> **Living docs (prefer these):** [DECISIONS.md](DECISIONS.md) · [ENGINEERING.md](ENGINEERING.md) · [LEXICON.md](LEXICON.md) · [ROADMAP.md](ROADMAP.md)  
> This file is older product doctrine and may drift. Do not reopen settled debates here — update DECISIONS.md instead.

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

## LifePoints Alignment Stack

The whole app is organized around aligned layers (LifePoints language only — no third-party admin/product labels in UI or docs copy):

```text
Goal (LifeJourney)
  → Ideal / Now (ideal_scene / current_reality)
  → Milestone (next_win, optional)
  → Mission (one-sitting)
  → Daily action (DailyTodo)
```

**Progress weight:** todo << mission << milestone << journey complete.

Day-to-day gap changes go through `Gap::ApplyProgress` (`:todo` / `:mission`) with absolute caps so small checkboxes cannot chew the mountain.

Inspired by the *idea* of visibility + daily battle lists; **not** a copy of any proprietary management system (no condition formulas, org boards, staff quotas, or trademarked product names).

## Journey self-setup

On the Journey page, users can fill an **editable alignment stack** themselves (plain LifePoints language):

Goal · Why it matters · Rules · Approach · Program · Milestone · Ideal / Now · Progress · Finished result · Today’s action

Optional text fields live on `life_journeys` (`purpose`, `policy`, `approach`, `program`, `finished_result`). No separate Plan/Program tables. No third-party admin product labels in the UI.

## Domain ownership

```text
Life Area  →  Life Journey (+ optional next_win)  →  Daily Mission (+ DailyTodos)
```

## MVP coach flow

1. Focus — which area first? (exactly one)
2. Journey — what do you want to achieve? → `title`
3. Vision — what does success look like? → `ideal_scene`
4. Reality — where are you today? → `current_reality`
5. Progress — how close? (default 5%) → `gap_percent = 100 - closer`
6. Milestone — next major step? (**optional**) → `next_win`
7. Mission — one thing today → Mission title
8. Dashboard — **Today** (mission + battle todos) + slim progress. No tree, no card stack.

No Project/Plan models. No stats wizard.

## One mountain at a time

- Onboarding picks **exactly one** Life Area, then the coach beats above.
- Default Focus is **one** Journey (set automatically).
- Completing a Journey is **user-declared** → LP + next mountain (same Area or new Area).

## MVP schema (lean)

Persisted now: `users` (+ `planning_version`), selected `life_areas`, `life_journeys` (Ideal/Present/`next_win`), Focus via `focus_position`, `missions`, `daily_todos`, LP ledger, `gap_snapshots`.

**Not** in MVP: Plan/Program/Project/Purpose/Policy/Statistic tables, generate-on-GET, habit LP for `planning_version = 2`, employee/org-board features.

## Strangler

- `planning_version = 1` — legacy Dream → Goal → Building → TodayAction
- `planning_version = 2` — Area → Journey → Mission loop; sole LP writer is the mission/todo award path

See also: design system under `docs/design/`.
