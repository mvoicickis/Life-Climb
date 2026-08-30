# frozen_string_literal: true

module AdminHelper
  def admin_initials(user)
    base = user.display_name.to_s
    parts = base.split(/\s+/).first(2)
    parts.map { |p| p[0] }.join.upcase.presence || "?"
  end

  def admin_last_seen(user)
    seen = user.try(:last_seen_at) || user.sessions.maximum(:updated_at)
    return t("admin.users.never_seen") if seen.blank?

    l(seen, format: :short)
  end

  def admin_onboarding_label(user)
    user.onboarding_completed? ? t("admin.users.onboarding_done") : t("admin.users.onboarding_pending")
  end

  def admin_funnel_activity_status(last_seen_at)
    return { level: :muted, label: t("admin.funnel.status_never") } if last_seen_at.blank?

    days_ago = (Date.current - last_seen_at.in_time_zone.to_date).to_i
    case days_ago
    when 0, 1
      { level: :green, label: t("admin.funnel.status_recent") }
    when 2..6
      { level: :amber, label: t("admin.funnel.status_stale") }
    else
      { level: :muted, label: t("admin.funnel.status_inactive") }
    end
  end
end
