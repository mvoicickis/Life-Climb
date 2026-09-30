# LifePoints Engineering Architecture

Lightweight engineering guide — how we build. Not product philosophy.

**Related**

- [DECISIONS.md](DECISIONS.md) — settled Accepted / Rejected product decisions
- [LEXICON.md](LEXICON.md) — player lexicon, eng↔player map, dual-name hotspots
- [ROADMAP.md](ROADMAP.md) — MVP milestone progress
- [ARCHITECTURE.md](ARCHITECTURE.md) — older product doctrine (may drift; prefer DECISIONS + constitutions)
- [design/DESIGN_SYSTEM.md](design/DESIGN_SYSTEM.md) — brand tokens / voice

---

## 1. Folder structure

```text
app/
  controllers/     # HTTP (admin/, developer/, concerns/)
  models/          # ActiveRecord (+ concerns/)
  services/        # Domain operations (Strategy::, Climb::, Ai::, …)
  views/           # ERB by controller; shared/ partials
  helpers/
  javascript/controllers/   # Stimulus (*_controller.js)
  assets/tailwind/application.css   # Tailwind v4 + --lp-* tokens
  jobs/, mailers/, channels/
config/            # routes, importmap, locales, ci
db/
test/              # mirrors app (controllers, models, services, system)
docs/              # ENGINEERING, DECISIONS, LEXICON, ROADMAP, design/, SECURITY
.github/workflows/ci.yml
```

**Rules:** Business logic → `app/services/`. UI → ERB partials + helpers. No ViewComponent. Do not invent new top-level app folders without need.

---

## 2. Rails conventions

**Controllers** — RESTful, thin; auth/onboarding in concerns; `Admin::` / `Developer::` only for those surfaces; prefer `html` + `turbo_stream` for in-place updates.

**Models** — persistence, validations, associations, simple queries. Workflows → services.

**Services** — `app/services/<domain>/<name>.rb` → `Domain::Name`. Entry: `.call(...)` or `.for(...)` matching neighbors. Examples: `Strategy::Mountain`, `Strategy::FirstClimb`, `Battles::CompleteDay`.

**Views** — one template family per controller; extract partials early; shared chrome in `app/views/shared/`. Player copy in `config/locales/`.

**Routes** — add next to related resources; prefer existing path helpers.

**Migrations** — small, reversible when practical. Do not change schema for copy/philosophy. Prefer presentation/services. No new permanent product areas via tables unless Feature Framework passed.

---

## 3. Component conventions (views)

ERB partials + helpers only (no ViewComponent).

| Pattern | Use |
|---------|-----|
| `_foo.html.erb` | Reusable chunk for one screen/domain |
| `shared/_*.html.erb` | Cross-screen chrome |
| Helpers | Formatting, kind maps, repeated conditionals |

Pass locals explicitly. One partial ≈ one responsibility. Player copy → `t(".key")`.

---

## 4. Stimulus conventions

| Item | Convention |
|------|------------|
| Location | `app/javascript/controllers/` |
| File | `descriptive_name_controller.js` |
| Identifier | `descriptive-name` |
| Registration | importmap `pin_all_from` + eager load |

Stimulus enhances server HTML; it does not own domain data. Keep controllers small. After Turbo Streams, use lifecycle hooks. Example: `strategy_rpg_controller.js` → `strategy-rpg`.

Avoid fetching business rules in JS; avoid god controllers for whole Mountain.

---

## 5. Turbo conventions

**Current:** Turbo Drive + Turbo Streams (`append` / `replace` / `update`). Occasional `Turbo.visit` from Stimulus. Frames / morph are **not** current standard — do not adopt mid-milestone unless acceptance criteria require it.

Prefer stream responses for create/update/complete that stay on-page. Keep stream templates small. `data-turbo-track="reload"` only for cache-busting assets.

---

## 6. Naming conventions

See [LEXICON.md](LEXICON.md) for the full eng↔player map and hotspots.

**Rule:** Never rename DB columns for lexicon. Change **copy and presentation** first.

CSS/JS: `--lp-*`, `.lp-*`; Stimulus snake_case file / kebab-case id; tests named by behavior.

---

## 7. CSS architecture

| Layer | Path |
|-------|------|
| Tailwind v4 + tokens | `app/assets/tailwind/application.css` |
| Tokens | `--lp-*` (see design system) |
| Feature utilities | `.lp-*`, screen namespaces (`.lp-strategy-*`, `.lp-dash-*`) |
| Propshaft sheet | `app/assets/stylesheets/application.css` (keep thin) |

Prefer existing tokens. Mobile-first. Respect `prefers-reduced-motion`. Do not restyle the whole app inside a non-polish milestone.

---

## 8. Testing strategy

| Layer | Location | When |
|-------|----------|------|
| Model | `test/models/` | Validations, kinds, invariants |
| Service | `test/services/<domain>/` | Domain workflows (preferred) |
| Controller | `test/controllers/` | Auth, redirects, streams |
| System | `test/system/` | Critical player paths |

Stack: Minitest + fixtures; system tests via Capybara + headless Chrome.

Every milestone locks its Acceptance Criteria with tests. CI: RuboCop, Brakeman, bundler-audit, importmap audit, tests.

**Daily-loop milestones (M1–M3):** complete Battle on Today; empty/never-empty plan if touched; auth-gated dashboard regression.

---

## 9. PR checklist

Use `.github/PULL_REQUEST_TEMPLATE.md` (same content). Every milestone PR must answer: **Which screen owns this?** (Responsibility Matrix in LEXICON.md).

---

## 10. Definition of Done

A milestone is Done only when:

1. Roadmap Acceptance Criteria met  
2. Milestone QA checklist run  
3. Tests added/updated; CI green  
4. No scope leak — only that milestone’s screen ownership  
5. Lexicon correct on touched player surfaces  
6. PR checklist completed  
7. Regression risks checked; deferred issues listed in PR  
8. Next milestone not started until this one is Done  

Not required unless the milestone is M11–M14: perfect animation, full a11y audit, full performance pass, launch ops.

---

## 11. Working rule

```text
Open docs/ROADMAP.md → pick next milestone → implement only that → PR checklist → Done → repeat
```

Settled product debates → [DECISIONS.md](DECISIONS.md).  
How we code → this file.  
What order → [ROADMAP.md](ROADMAP.md).
