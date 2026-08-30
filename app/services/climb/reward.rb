# frozen_string_literal: true

module Climb
  # Builds a short post-win climb reward payload for flash → UI.
  class Reward
    def self.for_battle(user:, awarded:, goal: nil, streak_days: nil, boss: false, personal_best: false, earned_freeze: false)
      mountain = Strategy::Mountain.for(goal: goal)
      status = Climb::Streak.status(user: user)
      {
        kind: boss ? "boss" : "battle",
        title: I18n.t(boss ? "climb.reward.boss_title" : "climb.reward.battle_title"),
        ap: awarded.to_i,
        percent: mountain[:progress].to_i,
        stage: mountain[:stage].to_s,
        stage_label: mountain[:label].to_s,
        streak: (streak_days.presence || status.days).to_i,
        freezes: status.freezes,
        personal_best: personal_best,
        earned_freeze: earned_freeze,
        cta: I18n.t("climb.reward.keep_fighting"),
        trail_cta: I18n.t("climb.reward.back_to_trail")
      }
    end

    def self.for_project(user:, goal:, percent_before:, percent_after:, stage_before: nil)
      mountain = Strategy::Mountain.for(goal: goal)
      boss = stage_before.present? && stage_before.to_s != mountain[:stage].to_s
      status = Climb::Streak.status(user: user)
      {
        kind: boss ? "boss" : "project",
        title: I18n.t(boss ? "climb.reward.boss_title" : "climb.reward.project_title"),
        ap: 0,
        percent: mountain[:progress].to_i,
        percent_delta: [ percent_after.to_i - percent_before.to_i, 0 ].max,
        stage: mountain[:stage].to_s,
        stage_label: mountain[:label].to_s,
        streak: status.days,
        freezes: status.freezes,
        personal_best: false,
        earned_freeze: false,
        cta: I18n.t("climb.reward.keep_fighting"),
        trail_cta: I18n.t("climb.reward.back_to_trail")
      }
    end
  end
end
