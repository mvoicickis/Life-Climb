---
name: Streak moment PR1-2
overview: PR 1 (`cursor/eod-off`) removes all End-of-day UI, replaces the End day slot with handoff-driven all-clear CTAs, and adds flame tokens + green pill depth. PR 2 (`cursor/streak-moment`, after PR 1 merges) adds `last_streak_moment_on`, eligibility/claim logic, and the mockup-faithful streak overlay on Today win streams and dashboard load only.
todos:
  - id: pr1-eod-ui-off
    content: "PR1 (cursor/eod-off): Remove EOD renders from show_v2, complete/completions streams; replace end-day partial with all-clear actions; ignore session keys in UI"
    status: completed
  - id: pr1-cta-tokens-css
    content: "PR1: EmptyBattleCta-driven pills + summit secondary link; :root flame tokens; today_v2 pill lip + 16px host padding; 5-locale keys"
    status: completed
  - id: pr1-tests
    content: "PR1: Update/remove EOD tests; add all-clear href, summit dual CTA, un-win empty host, legacy session normal Today tests"
    status: in_progress
  - id: pr2-migration-service
    content: "PR2 (cursor/streak-moment): Migration last_streak_moment_on; Today::StreakMoment eligible? + claim!"
    status: pending
  - id: pr2-overlay-ui
    content: "PR2: streak_moment partial + today_v2.css + streak_moment_controller.js; host in show_v2; turbo update on complete; dashboard show_v2 fallback"
    status: pending
  - id: pr2-share-tests
    content: "PR2: streak_moment_share_text helper + locales; wire shareRecap; tests for eligibility, streams, mountain quiet, Day 1, lifeclimb.app link"
    status: pending
isProject: false
---

# Streak moment — PR 1 and PR 2 plan

Approved UI: [docs/mockups/today-streak-moment.html](docs/mockups/today-streak-moment.html) (4 phones). Branches: **`cursor/eod-off`** (PR 1), then **`cursor/streak-moment`** (PR 2, base `origin/main` after PR 1 merge).

See `/home/mv/.cursor/plans/streak_moment_pr1-2_70d97d36.plan.md` for full file-level detail. PR 2 decisions (a–c) are in section 4–5 of that document:

- **(a)** Number always rolls `(days − 1) → days` on stream and page load; Day 1 → “First day of your climb”, no roll. Once per day after all battles won.
- **(b)** Overlay `bottom: nav height + safe-area`, not full inset + padding; nav stays tappable.
- **(c)** Share via overlay `data-streak-moment-share-text-value` + `streak_moment_controller#share`; not `#today-dash-root` recap text.
