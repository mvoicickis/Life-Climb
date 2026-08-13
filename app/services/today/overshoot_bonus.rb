# frozen_string_literal: true

module Today
  # Awards delta-only overshoot AP when day % exceeds the day's high-water mark.
  # Never claw back on falls. Call only from write paths — never from GET.
  class OvershootBonus
    RATE = 0.4
    DAILY_CAP = 50

    Result = Struct.new(:granted, :awarded_ap, :peak_percent, :percent, keyword_init: true)

    def self.sync!(user:, date: Date.current)
      new(user: user, date: date).sync!
    end

    def initialize(user:, date:)
      @user = user
      @date = date
    end

    def sync!
      percent = DayPercent.call(user: @user, date: @date).percent
      existing = DayOvershootBonus.find_by(user: @user, on_date: @date)

      if percent.nil? || percent <= 100
        return Result.new(
          granted: 0,
          awarded_ap: existing&.awarded_ap.to_i,
          peak_percent: existing&.peak_percent.to_i,
          percent: percent
        )
      end

      row = existing || DayOvershootBonus.new(user: @user, on_date: @date, peak_percent: 0, awarded_ap: 0)

      if percent <= row.peak_percent
        return Result.new(
          granted: 0,
          awarded_ap: row.awarded_ap,
          peak_percent: row.peak_percent,
          percent: percent
        )
      end

      target_ap = [ DAILY_CAP, ((percent - 100) * RATE).round ].min
      delta = target_ap - row.awarded_ap

      ActiveRecord::Base.transaction do
        row.save! if row.new_record?

        if delta.positive?
          LifePoints::Award.call(
            user: @user,
            amount: delta,
            reason: I18n.t("life_points.reasons.overshoot", percent: percent),
            source: row
          )
          row.awarded_ap += delta
        end

        row.peak_percent = percent
        row.save!
      end

      Result.new(
        granted: [ delta, 0 ].max,
        awarded_ap: row.awarded_ap,
        peak_percent: row.peak_percent,
        percent: percent
      )
    end
  end
end
