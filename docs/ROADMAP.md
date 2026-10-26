# LifePoints MVP Roadmap

Living implementation order. Constitutions are stable. Update this file only to mark progress or adjust priority from implementation / user feedback.

Full milestone specs live in the approved MVP Roadmap plan; this file is the **progress board**.

**Workflow:** one milestone per cycle → review → fix only that milestone → QA → merge → next.

---

## Definitions

**MVP:** Daily loop works — Mountain orient → Mission → Today’s Battle Plan (one plan, multiple Battles) → win → return tomorrow without shame or empty dead-end.

**Production Ready:** MVP + continuity polish as needed + a11y baseline + performance + launch checklist (M10–M14).

---

## Milestones

| ID | Milestone | Complexity | Status |
|----|-----------|------------|--------|
| M0 | Lexicon + Screen Ownership Baseline | Small | **Done** (this PR) |
| M1 | Today’s Battle Plan (One Battle Plan Law) | Medium | Pending |
| M2 | Battle Completion → Visible Progress | Medium | Pending |
| M3 | Return Tomorrow + Never-Empty Plan | Medium | Pending |
| M4 | Mountain Orientation Pass | Medium | Pending |
| M5 | Destination Utility Lock | Small | Pending |
| M6 | Mission Enter (Accept Mission) | Medium | Pending |
| M7 | Mission & Destination Completion Beats | Medium | Pending |
| M8 | Journey Chronicle Pass | Small | Pending |
| M9 | Character Satellite Pass | Small | Pending |
| M10 | Cross-Screen Continuity Polish | Medium | Pending |
| M11 | Intentional Motion Pass | Medium | Pending |
| M12 | Accessibility Baseline | Medium | Pending |
| M13 | Performance Pass | Medium | Pending |
| M14 | Launch Readiness | Medium | Pending |

**MVP ship gate:** M0–M7 (M8–M9 thin / not broken).  
**Production Ready gate:** through M14.

---

## Critical path

```text
M0 → M1 → M2 → M3
M0 → M4 → M5 → M6 → M7
then M8, M9 → M10 → M11/M12/M13 → M14
```

Prefer daily loop (M1–M3) before Mountain polish if only one engineer.

---

## M0 acceptance (this milestone)

- [x] `docs/DECISIONS.md` filed
- [x] `docs/ENGINEERING.md` filed
- [x] Critical-path lexicon + eng↔player map (`docs/LEXICON.md`)
- [x] Dual-name hotspots listed for fix-as-you-touch
- [x] PR checklist includes Responsibility Matrix + DECISIONS gate
- [x] QA: nav labels are Mountain · Today · Journey · You; hotspot keys present in `en.yml`
- [x] Tests lock docs + nav lexicon (`test/integration/m0_lexicon_baseline_test.rb`)

---

## Next

**M1 – Today’s Battle Plan** (One Battle Plan Law).
