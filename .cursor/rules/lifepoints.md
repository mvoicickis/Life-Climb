# LifePoints

Rails 8, Hotwire/Turbo, importmap, Tailwind. SQLite local, Postgres on Render.

## Workflow
- Investigate (Ask) before building when a bug's cause isn't clear
- Reuse existing models/partials before creating new ones
- Small PRs, one concern per branch
- Confirm scope before large builds

## Product rules
- Progress framed as encouragement, never deficit
- Numbers only count up, bars never shrink, missing a day carries no penalty
- User-facing words: goal, camp, battle. Never project, checkpoint, plan.
- Never ship copy that tells the user to do something that doesn't work
- Copy simple enough for an 8-year-old

## Environment
- Never run headless Chrome, take screenshots, or start a web server to
  verify HTML. It hangs. Write the file, report the path, I open it myself.
- Cursor's cloud workspace has a separate database from local
- gh pr create fails with GraphQL permissions — open PRs via web

## Style
- Keep responses short. Don't restate repo facts you can read yourself.
- Lead with the risk, not a task recipe.

## Reporting
- "Merged" means gh pr view says MERGED. Verify before claiming it.
- Always report the FULL local suite count, not just targeted files.
- Never report a bug fixed based on green tests alone. Say what you changed;
  I verify on device.

## Debugging
- Get the actual exception class and message before theorising. Production
  console beats inference.
- When a fix doesn't hold, check the environment first — deploy state,
  cache, stale local repo — before re-diagnosing.

## Scope
- One concern per PR. If a plan touches more than ~5 files or mixes a bug
  fix with a refactor, split it and say why.
