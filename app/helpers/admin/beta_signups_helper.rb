# frozen_string_literal: true

module Admin
  module BetaSignupsHelper
    def beta_signups_index_path(filter:)
      admin_beta_signups_path(filter: filter)
    end

    def beta_signups_filter_class(active_filter, current_filter)
      classes = [ "lp-admin__btn" ]
      classes << "is-active" if active_filter == current_filter
      classes.join(" ")
    end

    def admin_beta_signup_source_label(signup)
      path = signup.source_path.to_s.strip

      if path.blank? || path == "/"
        return t("admin.beta_signups.source.landing")
      end
      if path == "/blog" || path.match?(%r{\A/blog/?\z})
        return t("admin.beta_signups.source.blog_list")
      end
      if path.start_with?("/blog/")
        return t("admin.beta_signups.source.blog_post")
      end

      path.presence || t("admin.beta_signups.source.unknown")
    end

    def admin_beta_signup_device_label(device)
      return t("admin.beta_signups.device.unknown") if device.blank?

      t("admin.beta_signups.device.#{device}", default: t("admin.beta_signups.device.unknown"))
    end
  end
end