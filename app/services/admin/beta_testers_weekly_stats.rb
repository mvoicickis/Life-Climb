# frozen_string_literal: true

module Admin
  # Berlin-week stats for Karen (invites) and Mareks (daily climbers) on the beta testers page.
  class BetaTestersWeeklyStats
    DAY_ZONE = Testers::DAY_ZONE
    GOAL = Testers::DAILY_CLIMBERS_GOAL

    KarenWeek = Data.define(:invites_sent, :became_testers)
    MareksWeek = Data.define(:daily_climbers, :goal, :won_today)
    WeekPair = Data.define(:this_week, :last_week)
    FunnelStep = Data.define(:key, :label, :owner, :count)

    def self.call(berlin_today: Testers.berlin_today)
      new(berlin_today: berlin_today).call
    end

    def initialize(berlin_today:)
      @berlin_today = berlin_today.to_date
      @this_week_monday = @berlin_today.beginning_of_week(:monday)
      @last_week_monday = @this_week_monday - 7.days
    end

    def call
      tester_user_ids = BetaTester.where.not(user_id: nil).pluck(:user_id).to_set
      this_dates = (@this_week_monday..@berlin_today).to_a
      last_dates = (@last_week_monday..(@last_week_monday + 6.days)).to_a
      climber_days = climbers_by_day(this_dates + last_dates)

      {
        karen: WeekPair.new(
          this_week: karen_week(week_monday: @this_week_monday, week_end: @berlin_today),
          last_week: karen_week(week_monday: @last_week_monday, week_end: @last_week_monday + 6.days)
        ),
        mareks: WeekPair.new(
          this_week: mareks_week(
            tester_user_ids: tester_user_ids,
            dates: this_dates,
            climber_days: climber_days,
            include_won_today: true
          ),
          last_week: mareks_week(
            tester_user_ids: tester_user_ids,
            dates: last_dates,
            climber_days: climber_days,
            include_won_today: false
          )
        ),
        funnel: funnel_rows(
          tester_user_ids: tester_user_ids,
          this_dates: this_dates,
          climber_days: climber_days
        )
      }
    end

    private

    def karen_week(week_monday:, week_end:)
      range = berlin_time_range(week_monday, week_end)

      KarenWeek.new(
        invites_sent: User.excluding_privileged.where(beta_invited_at: range).count,
        became_testers: became_testers_count(range)
      )
    end

    def became_testers_count(time_range)
      BetaTester.joins(:user)
        .where.not(users: { beta_invited_at: nil })
        .where("beta_testers.added_at > users.beta_invited_at")
        .where(beta_testers: { added_at: time_range })
        .count
    end

    def mareks_week(tester_user_ids:, dates:, climber_days:, include_won_today:)
      daily_climbers = daily_climber_count(tester_user_ids, dates, climber_days)
      won_today =
        if include_won_today
          (tester_user_ids & climber_days.fetch(@berlin_today, Set.new)).size
        else
          0
        end

      MareksWeek.new(daily_climbers: daily_climbers, goal: GOAL, won_today: won_today)
    end

    def daily_climber_count(tester_user_ids, dates, climber_days)
      return 0 if tester_user_ids.empty? || dates.empty?

      tester_user_ids.count do |user_id|
        dates.all? { |date| climber_days.fetch(date, Set.new).include?(user_id) }
      end
    end

    def climbers_by_day(dates)
      unique_dates = dates.uniq
      unique_dates.index_with { |date| Testers.climber_user_ids_for_day(date) }
    end

    def funnel_rows(tester_user_ids:, this_dates:, climber_days:)
      user_ids = User.excluding_privileged.pluck(:id)
      profiles = Testers.device_profiles_for(user_ids)
      android_ids = user_ids.select { |id| profiles.dig(id, :primary) == DeviceFromUserAgent::DEVICE_ANDROID }

      android_signed_up = android_ids.size
      invited = User.where(id: android_ids).where.not(beta_invited_at: nil).count
      testers = BetaTester.where.not(user_id: nil).count
      daily_climbers = daily_climber_count(tester_user_ids, this_dates, climber_days)

      [
        FunnelStep.new(
          key: :android_signed_up,
          label: I18n.t("admin.beta_testers.funnel.android_signed_up"),
          owner: nil,
          count: android_signed_up
        ),
        FunnelStep.new(
          key: :invited,
          label: I18n.t("admin.beta_testers.funnel.invited"),
          owner: I18n.t("admin.beta_testers.funnel.owner_karen"),
          count: invited
        ),
        FunnelStep.new(
          key: :testers,
          label: I18n.t("admin.beta_testers.funnel.testers"),
          owner: nil,
          count: testers
        ),
        FunnelStep.new(
          key: :daily_climbers,
          label: I18n.t("admin.beta_testers.funnel.daily_climbers"),
          owner: I18n.t("admin.beta_testers.funnel.owner_mareks"),
          count: daily_climbers
        )
      ]
    end

    def berlin_time_range(start_date, end_date)
      zone = Time.find_zone!(DAY_ZONE)
      start_at = zone.local(start_date.year, start_date.month, start_date.day).beginning_of_day
      end_at = zone.local(end_date.year, end_date.month, end_date.day).end_of_day
      start_at..end_at
    end
  end
end
