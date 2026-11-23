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

    def beta_testers_trend(current, previous)
      if current > previous
        :up
      elsif current < previous
        :down
      else
        :same
      end
    end

    def beta_testers_trend_mark(trend)
      case trend
      when :up then "↑"
      when :down then "↓"
      else "="
      end
    end

    def beta_testers_trend_delta(current, previous)
      delta = current.to_i - previous.to_i
      mark = beta_testers_trend_mark(beta_testers_trend(current, previous))
      "#{mark} #{delta.abs}"
    end

    def beta_testers_progress_percent(count, goal)
      return 0 if goal.to_i <= 0

      ((count.to_f / goal) * 100).clamp(0, 100).round
    end
  end
end
