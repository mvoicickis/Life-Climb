# frozen_string_literal: true

module Admin
  module BetaTestersHelper
    def beta_testers_tier_label(tier)
      case tier
      when BetaTestersRoster::TIER_RECENT_WIN
        t("admin.beta_testers.tier.recent_win")
      when BetaTestersRoster::TIER_NEVER_WON
        t("admin.beta_testers.tier.never_won")
      else
        t("admin.beta_testers.tier.other")
      end
    end

    def beta_testers_last_win_label(last_win_at)
      return t("admin.beta_testers.never_won") if last_win_at.blank?

      l(last_win_at.to_date, format: :long)
    end

    def beta_testers_play_label(play_app)
      play_app ? t("admin.beta_testers.play_yes") : t("admin.beta_testers.play_no")
    end
  end
end
