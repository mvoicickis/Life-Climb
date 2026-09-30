# LifePoints Lexicon + Screen Ownership

M0 baseline. Player language is locked. Engineering names may differ — change **copy first**, not schema.

Settle debates in [DECISIONS.md](DECISIONS.md). Coding rules in [ENGINEERING.md](ENGINEERING.md).

---

## Player lexicon (critical path)

| Player name | Meaning |
|-------------|---------|
| **Mountain** | The adventure world |
| **Destination / Summit** | Where this climb is going |
| **Mission** | Campaign that serves a Destination |
| **Battle** | One winnable fight inside a Mission |
| **Today’s Battle Plan** | One daily plan (may contain multiple Battles) |
| **Journey** | History / progress ledger |
| **You / Character** | Identity and account |

Nav tabs today: **Mountain · Today · Journey · You**.  
Mission is **entered from Mountain**. Destination is **utility on Mountain**. Battle is **fought from Today’s Battle Plan**.

---

## Eng ↔ player map

| Engineering | Player |
|-------------|--------|
| `LifeJourney` show | Mountain |
| `StrategyGoal` `kind=goal` | Destination |
| `StrategyGoal` `kind=plan` | Mission |
| `StrategyGoal` `kind=project` | Stage inside Mission (minimize in player copy) |
| `StrategyGoal` `kind=day` | Battle |
| `DailyTodo` / dashboard | Today’s Battle Plan |
| `LifePointsController` progress | Journey (ledger — not the Mountain model) |
| Settings | Character / You |

---

## Screen ownership (Responsibility Matrix)

| Responsibility | Owner |
|----------------|--------|
| Orient in world | Mountain |
| Choose / focus Summit | Destination (utility on Mountain) |
| Accept / advance campaign | Mission |
| Define today’s fights | Today’s Battle Plan |
| Win one fight | Battle |
| Record history | Journey |
| Identity / account | Character |
| Return-tomorrow hook | Today’s Battle Plan (primary) |

**PR rule:** Only one owner per change. If two screens claim it → simplify.

---

## Dual-name hotspots (fix-as-you-touch)

Do **not** big-bang rewrite in M0. When a milestone touches a surface, replace player-facing “Plan/Plans” with **Mission/Missions** (and align related CTAs). Leave DB `kind=plan`, params like `plan_id`, and internal CSS/Stimulus names alone unless the milestone requires them.

### Critical path — high priority

| Location | Current player copy (examples) | Target |
|----------|--------------------------------|--------|
| `strategy.rpg.plans_kicker` | “Plans on this trail” | Missions on this trail |
| `strategy.rpg.add_plan` | “+ Add new plan” | + Add Mission |
| `strategy.rpg.pick_checkpoint` | “Pick a plan on this trail” | Pick a Mission… |
| `strategy.rpg.projects_kicker` | “Projects in %{plan}” | Stages in %{mission} (minimize Project jargon) |
| `strategy.next_up.enter_plan_cta` | “Enter Plan” | Accept Mission / Enter Mission |
| `strategy.next_up.add_plan_*` | Add your first plan / Add a plan | Add Mission |
| `strategy.next_up.open_plan_*` | Enter/open plan | Enter Mission |
| `strategy.horizons.plan` | “Plan” | Mission |
| `strategy.levels.plan` | “Plans” | Missions |
| `strategy.zones.plans` / `add_plan_hint` | Plans / Add a plan… | Missions |
| `strategy.sheet.add_plan` | (sheet add plan CTA) | Add Mission |
| `strategy.first_climb.plan_*` | First-climb plan labels | Mission wording |
| `strategy.hierarchy_gate.notice` | “Name your next plan…” | Name your next Mission… |
| How-guide (`how_stack_body`, plan example labels) | Goals, Plans, Projects… | Destination, Mission, … |
| Nav / Today titles | Mixed “Today’s Battle” vs plan | Prefer **Today’s Battle Plan** for the container |
| `nav.building: "Plan"` | Plan | Not a permanent peer screen |

### Medium priority (when touched)

| Location | Notes |
|----------|--------|
| `strategy.notebook.*` / camp notebook | “plan” in open/empty copy |
| AI suggest CTAs (`suggest_plan`, `use_plan`) | Player-facing → Mission |
| Progress `plans_completed` | Prefer Missions completed |
| Adventure guide hint | Plans/Projects language |
| Internal partial names (`_rpg_plan_rail`) | Eng-only OK; visible strings must say Mission |

### Leave alone (engineering)

- DB `kind` values: `goal`, `plan`, `project`, `day`
- URL/query params: `goal_id`, `plan_id`
- Ruby methods: `plan?`, `plans`, Stimulus `strategy-plan-rail`, CSS `.lp-rpg-plan-rail`
- Service class names unless renaming is the milestone

---

## One Battle Plan Law (copy reminder)

- Today centers on **one** Battle Plan.
- That plan may contain **multiple** Battles.
- Today is never an unbounded inbox.
- Supersedes “One Fight Law.”
