# AGENTS.md

## Cursor Cloud specific instructions

LifePoints is a single Ruby on Rails 8.1 web app (a personal "life operating
system" / goal + daily-action tracker). There is only one service. It uses
SQLite in development and test (no external database needed); Postgres is only
used in production.

### Environment notes (already provisioned by the startup update script)

- Ruby 4.0.6 is compiled and installed into `/usr/local`, so `ruby`, `gem`, and
  `bundle` are on the default `PATH` (no version manager / no shell profile
  changes needed).
- Gems install into `vendor/bundle` (a repo-local `bundle config path`, which is
  gitignored). The startup update script runs `bundle install`.
- No `RAILS_MASTER_KEY` is required for development or test.
- The SQLite dev/test databases live under `storage/` (gitignored, persisted in
  the VM snapshot). If they are ever missing or you need a clean slate, run
  `bin/rails db:prepare` (create + load schema + seed) or `bin/rails db:reset`.

### Running the app

- Start the dev server with `bin/dev` (see `Procfile.dev`); it runs Puma on
  `http://localhost:3000` plus the Tailwind CSS watcher.
- GOTCHA: `bin/dev` needs the `foreman` gem. `foreman` is intentionally NOT in
  the `Gemfile`, so `bin/dev` tries to `gem install foreman` on first run. In
  this environment that lands in a user gem dir that is not on `PATH`, and
  `bin/dev` then fails with `exec: foreman: not found`. `foreman` is
  pre-installed globally here to avoid this. If you ever see that error, run
  `sudo gem install foreman` once (installs to `/usr/local/bin`).

### Lint, security, and tests (commands already defined in the repo)

- Lint: `bin/rubocop` (rubocop-rails-omakase).
- Security scans (mirrors CI in `.github/workflows/ci.yml`): `bin/brakeman`,
  `bin/bundler-audit`, `bin/importmap audit`.
- Unit/integration tests: `bin/rails test` (runs in parallel).
- System tests: `bin/rails test:system` — these drive headless Chrome via
  Capybara/Selenium (Chrome is installed). They are slower and can be viewport /
  timing sensitive.

### Seeded accounts (from `db/seeds.rb`)

- Demo user: `demo@lifepoints.test` / `password12345`
- Admin user: `admin@lifepoints.test` / `password12345` (admin area at `/admin`)
- Passwords come from `DEMO_PASSWORD` / `ADMIN_PASSWORD` env vars, defaulting to
  `password12345` in non-production.
