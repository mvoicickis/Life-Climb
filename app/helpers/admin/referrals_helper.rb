# frozen_string_literal: true

module Admin
  module ReferralsHelper
    def admin_referral_link_for(user)
      code = ERB::Util.url_encode(user.referral_code.to_s)
      "#{CanonicalHost.base_url}/?r=#{code}"
    end

    def admin_referral_first_win_label(at)
      at.present? ? l(at.to_date, format: :long) : t("admin.referrals.dash")
    end

    def admin_referral_last_opened_label(on)
      on.present? ? l(on, format: :long) : t("admin.referrals.dash")
    end
  end
end