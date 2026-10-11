# Privacy facts (internal)

Facts for writing the public privacy policy. Not user-facing.

## Data stored in our database (Render Postgres)

### Account (`users`)

- Email, name, password hash (`password_digest`)
- Locale, theme, companion character, onboarding flags, planning version
- Streaks, shields, points, install/push-offer counters
- Two-factor: `otp_secret`, `otp_enabled_at`, `otp_backup_codes_digest`
- Billing fields: `stripe_customer_id`, `stripe_subscription_id`, `subscription_status`, `current_period_end`
- Admin/developer flags

### Journey and climb (v2)

- `life_journeys`: titles, scenes, strategy brief JSON, status; optional `mountain_photo` (Active Storage)
- `life_areas`, `strategy_goals` tree (Journey / Camp / Battle horizons), quantity logs, daily todos
- `missions`, `journey_targets`, `gap_snapshots`, `pattern_snapshots`
- Legacy v1 data may still exist for some accounts: `dreams`, `goals`, `steps`, `buildings`, etc. (all `dependent: :destroy` on user)

### Basics

- `habits` (Basics): name, units, goals, links to camps
- `completions`, `daily_logs` per habit/day

### Time zone

- `notification_preferences.time_zone` (IANA), plus quiet hours, vacation, nudge flags

### Sessions (`sessions`)

- `ip_address`, `user_agent`, timestamps
- Login cookie `session_id` (signed, HttpOnly); rows expire after **30 days** of inactivity (see `Authentication::SESSION_TTL`)

### Product events (`user_events`)

- `name`, JSON `properties`, optional `user_id`
- Anonymous events possible (e.g. `landing_viewed`, `signup_started` without user)

### Feedback (`feedbacks`)

- `body`, optional `rating`, `page_context`, `app_version`, `contact_info`, `ok_to_contact`, optional `user_id`

### Push (`push_subscriptions`)

- Web Push `endpoint`, `p256dh`, `auth`, `user_agent`, `last_seen_at`

## Where data goes (processors / third parties)

| Destination | What |
|-------------|------|
| **Render** | App hosting, Postgres, request logs to STDOUT |
| **Stripe** | Customer id, subscription id/status; Checkout `client_reference_id` = user id; customer email + metadata on create |
| **SMTP** (env-configured) | Password reset, feedback to `FEEDBACK_TO_EMAIL` |
| **Browser push services** | Push payloads to subscription endpoints (often `fcm.googleapis.com`) |
| **AI provider** (`Ai::Client`, default OpenRouter) | Goal/journey text from `StrategyHelpsController` → `Ai::StrategyService` (user-triggered, suggestions only) |
| **Self-hosted fonts** | Nunito woff2 and CSS served from our origin (`/fonts/`) — no third-party font CDN |

No embedded Stripe.js. Share sheet may open Facebook/Messenger URLs (user-initiated).

## Cookies and browser storage

### Cookies

- `session_id` — auth session id (signed, HttpOnly, ~30 days)
- `locale` — UI language (permanent, HttpOnly)
- Rails session cookie — return-after-login, pending 2FA, impersonation, short-lived UI state

### localStorage

- `lpPageCacheUserId` — bind offline page cache to user
- `lpLegacyHostBannerSnoozeUntil` — snooze legacy host banner

### sessionStorage

- `lpAppWelcomeShown` — PWA welcome once
- `lpJuicySuppressCelebrate` — skip duplicate battle celebration after reload
- `lp-mountain-trail-scroll` — mountain trail scroll position
- `lp-path-rail-scroll:*` / `lp-snap-scroll:*` — horizontal rail scroll positions

### Cache API

- Service worker page cache keys `lifepoints-*-pages` (offline snapshots)

## Retention

- **Sessions:** 30-day TTL on use; row destroyed when expired on next request
- **Other user data:** until account deletion (no automated purge job for events/feedback/game data)
- **Account deletion:** `Accounts::DestroyUser` cancels Stripe subscription then `user.destroy!` (cascades per `User` associations). Does not delete anonymous `user_events`, Stripe customer record at Stripe, or copies in email/logs

## Code references

- `app/controllers/concerns/authentication.rb` — session cookie and TTL
- `app/controllers/concerns/set_locale.rb` — locale cookie
- `app/services/accounts/destroy_user.rb`
- `app/mailers/feedback_mailer.rb` — `FEEDBACK_TO_EMAIL`
- `app/jobs/send_web_push_job.rb`
