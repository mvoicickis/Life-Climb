# frozen_string_literal: true

# LifePoints Security Audit Report
# Generated as part of application hardening. Re-run Brakeman / bundler-audit regularly.

## Scope

Full review of authentication, authorization, sessions, input validation, secrets,
headers, rate limiting, production config, logging, and dependency hygiene for a
Rails 8.1 public deployment.

## Summary

| Severity | Open | Fixed in this pass |
|---|---|---|
| Critical | 0 | 0 |
| High | 0 | 4 |
| Medium | 1 residual | 8 |
| Low | several residual | several |

**Brakeman:** clean (0 warnings) prior to this pass  
**bundler-audit:** clean (0 CVEs)  
**Authorization:** controllers consistently scope by `current_user` — no IDOR found

---

## Findings

### HIGH — Fixed

#### H1. Weak password policy
- **Why:** Short passwords are trivial to brute-force offline if digests leak.
- **Risk:** Account takeover.
- **Fix:** `User` now requires password length 12–72; email format validated.
- **Status:** Fixed (`app/models/user.rb`)

#### H2. Registration not rate-limited
- **Why:** Unbounded signup enables spam accounts and bcrypt CPU DoS.
- **Risk:** Abuse / availability.
- **Fix:** `rate_limit` on registration + Rack::Attack throttles on `/registration`.
- **Status:** Fixed

#### H3. Default admin password in seeds
- **Why:** Production seed with `password` creates a trivial admin.
- **Risk:** Full compromise.
- **Fix:** Seeds refuse production without strong `ADMIN_PASSWORD`; never print passwords.
- **Status:** Fixed (`db/seeds.rb`)

#### H4. Auth rate limits only in-process (documented + layered)
- **Why:** `memory_store` does not share limits across dynos.
- **Risk:** Throttles weaker under horizontal scale.
- **Fix:** Added Rack::Attack (uses `Rails.cache`). Recommend Redis/Solid Cache when scaling.
- **Status:** Mitigated; shared cache still recommended for multi-dyno (see residual M1)

### MEDIUM — Fixed

#### M1. CSP disabled → enabled
- **Fix:** CSP with restrictive defaults + Google Fonts allowlist (`content_security_policy.rb`)
- **Status:** Fixed (style-src still allows `unsafe_inline` for Tailwind — tighten later)

#### M2. No global request throttling
- **Fix:** Rack::Attack IP / login / registration / password / write throttles
- **Status:** Fixed

#### M3. Over-broad `*.onrender.com` hosts
- **Fix:** Prefer exact `APP_HOST` / `RENDER_EXTERNAL_HOSTNAME`
- **Status:** Fixed

#### M4. Permanent sessions never expire
- **Fix:** 30-day session TTL; cookie expiry; session fixation rotation on login
- **Status:** Fixed (`Authentication`)

#### M5. Thin validations on spine models
- **Fix:** Max lengths on titles/summaries; habit points capped 1–100
- **Status:** Fixed

#### M6. Support milestone param injection
- **Fix:** Whitelist against `SupportMoment::MILESTONES`
- **Status:** Fixed

#### M7. Ship params not strong-param’d
- **Fix:** `ship_params` permit list
- **Status:** Fixed

#### M8. Parameter filter gaps
- **Fix:** Expanded filter list (passwords, email_address, session_id, …)
- **Status:** Fixed

### MEDIUM — Residual

#### R1. Shared cache for rate limits (multi-dyno)
- **Why:** Current production uses `memory_store`.
- **Risk:** Limits per process only.
- **Recommendation:** When scaling, set Redis or Solid Cache and point Rack::Attack at it.
- **Status:** Open (architecture-ready)

### LOW — Fixed / improved

- Open redirect: return path restricted to relative in-app paths
- Locale cookie: httponly + secure + same_site
- Admin soft-deny → `404` for non-admins
- Password reset `update` rate-limited
- Secure headers: X-Frame-Options DENY, nosniff, Referrer-Policy, Permissions-Policy

### LOW — Residual

- Contact helper still has founder email/WhatsApp defaults (override via ENV in prod)
- `image_processing` / `jbuilder` / `pagy` lightly used or unused — optional cleanup
- Chart `innerHTML` only with I18n date labels today — keep free of user strings
- Active Storage local disk — switch to S3/R2 before enabling uploads
- Payments not present yet — when added, use Stripe (PCI SAQ-A), never store card data

---

## Already strong (pre-hardening)

- bcrypt via `has_secure_password`
- Signed session cookie: HttpOnly, SameSite=Lax, Secure in production
- CSRF protection (Rails default) + csrf meta tags
- Ownership scoping on habits, buildings, actions, finished products, dreams, goals
- Admin not mass-assignable via registration/settings
- `force_ssl` + HSTS path via Rails in production
- Password reset does not reveal whether email exists
- Reset invalidates all sessions
- No app-level SQL string interpolation of user input
- No `html_safe` / `raw` in app views
- Credentials encrypted; `.env` / master.key gitignored

---

## Production checklist

1. Set `APP_HOST` to the canonical hostname  
2. Set strong `ADMIN_EMAIL` / `ADMIN_PASSWORD` (12+ chars) before any seed  
3. Set `SECRET_KEY_BASE` via Rails credentials / platform secrets  
4. Set `BUY_ME_A_COFFEE_URL` if using Support  
5. When scaling beyond one dyno: shared cache for Rack::Attack  
6. Before file uploads: object storage + content-type/size validation  
7. Run regularly: `bin/brakeman` and `bundle exec bundler-audit`

---

## Goal alignment

LifePoints is positioned for public launch with real users: least privilege on data,
throttled auth, validated input, secure cookies/sessions, CSP + security headers,
and no secrets in git. Remaining items are scale/ops upgrades, not launch blockers.
