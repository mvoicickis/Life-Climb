# frozen_string_literal: true

module Today
  # Once-per-local-day celebration after the first strategy-battle win of the day,
  # when Battles::DaysInARow is at least 2. Marks users.last_streak_moment_on.
  class StreakMoment
    Result = Struct.new(:days, :from_days, :week, :goal_title, keyword_init: true)

    def self.eligible?(user:)
      new(user:).eligible?
    end

    def self.present_for!(user:, goal_title:)
      new(user:).present_for!(goal_title: goal_title)
    end

    def initialize(user:)
      @user = user
    end

    def eligible?
      return false if read_only?

      today = local_today
      return false if @user.last_streak_moment_on == today
      return false if Battles::DaysInARow.count(user: @user) < 2

      won_today?
    end

    def present_for!(goal_title:)
      return nil if read_only?

      today = local_today
      return nil if @user.last_streak_moment_on == today

      days = Battles::DaysInARow.count(user: @user)
      return nil if days < 2
      return nil unless won_today?

      week = Stats::BattleWins.call(user: @user).this_week
      @user.update!(last_streak_moment_on: today)

      Result.new(
        days: days,
        from_days: [ days - 1, 1 ].max,
        week: week,
        goal_title: goal_title.to_s
      )
    end

    private

    def local_today
      Battles::WinsOnLocalDate.local_today_for(@user)
    end

    def won_today?
      zone = Battles::WinsOnLocalDate.time_zone_for(@user)
      Battles::WinsOnLocalDate.count_for_date(
        user: @user,
        date: local_today,
        time_zone: zone
      ).positive?
    end

    def read_only?
      # Survive a deploy where code ships before migrate finishes.
      !@user.has_attribute?(:last_streak_moment_on)
    end
  end
end
