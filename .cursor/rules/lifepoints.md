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
