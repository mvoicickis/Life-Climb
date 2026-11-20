# frozen_string_literal: true

module Admin
  # Beta-tester triage rows for Mareks and Karen.
  # Product wins only (Battles::WinsOnLocalDate sources) — never the broader funnel.
  class Testers
    STALE_AFTER_DAYS = 3
    PUSH_OK_WITHIN = 7.days
    DAILY_CLIMBERS_GOAL = 12
    DAY_ZONE = "Europe/Berlin"
    RECURRING_REPEATS = Battles::WinsOnLocalDate::RECURRING_REPEATS
    FILTER_NEEDS_MESSAGE = "needs_message"
    FILTER_EVERYONE = "everyone"
    FILTERS = [ FILTER_NEEDS_MESSAGE, FILTER_EVERYONE ].freeze
    DEVICE_FILTER_ALL = "all"
    DEVICE_FILTER_ANDROID = "android"
    DEVICE_FILTER_IPHONE = "iphone"
    DEVICE_FILTER_COMPUTER = "computer"
    DEVICE_FILTER_PLAY = "play"
    DEVICE_FILTERS = [
      DEVICE_FILTER_ALL,
      DEVICE_FILTER_ANDROID,
      DEVICE_FILTER_IPHONE,
      DEVICE_FILTER_COMPUTER,
      DEVICE_FILTER_PLAY
    ].freeze
    DEVICE_ORDER = [
      DeviceFromUserAgent::DEVICE_ANDROID,
      DeviceFromUserAgent::DEVICE_IPHONE,
      DeviceFromUserAgent::DEVICE_COMPUTER
    ].freeze
    PLAY_TESTERS_URL =
      "https://play.google.com/console/u/0/developers/7962663201417265259/app/4975708625747728285/tracks/4699763347313539783?tab=testers"

    Row = Data.define(
      :user,
      :contact,
      :signed_up_at,
      :onboarding_done,
      :first_win_at,
      :last_win_at,
      :wins_this_week,
      :last_opened_on,
      :days_since_open,
      :push_status,
      :partner,
      :reason_key,
      :reason,
      :days_since_last_win,
      :primary_device,
      :devices
    )

    def self.call(filter: FILTER_NEEDS_MESSAGE, device: DEVICE_FILTER_ALL)
      new(filter: filter, device: device).call
    end

    # Berlin calendar day → { testers:, admins: } unique climber counts.
    # Two win queries for the month + one privileged-id query; bucketed in Ruby.
    def self.counts_by_day(month:)
      new.counts_by_day(month: month)
    end

    def self.device_dashboard_stats(berlin_today:)
      new.device_dashboard_stats(berlin_today: berlin_today)
    end

    def self.berlin_today
      Time.find_zone!(DAY_ZONE).today
    end

    def self.goal_tier(testers_count)
      n = testers_count.to_i
      return :zero if n <= 0
      return :partial if n < DAILY_CLIMBERS_GOAL

      :met
    end

    def initialize(filter: FILTER_NEEDS_MESSAGE, device: DEVICE_FILTER_ALL)
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : FILTER_NEEDS_MESSAGE
      @device = DEVICE_FILTERS.include?(device.to_s) ? device.to_s : DEVICE_FILTER_ALL
    end

    def call
      rows = sort_rows(build_rows)
      rows = rows.select { |row| matches_device_filter?(row) } unless @device == DEVICE_FILTER_ALL
      return rows if @filter == FILTER_EVERYONE

      rows.select { |row| needs_message?(row) }
    end

    def device_dashboard_stats(berlin_today:)
      tester_ids = User.excluding_privileged.pluck(:id)
      profiles = device_profiles_for(tester_ids)
      climber_ids = tester_climber_ids_for_day(berlin_today)
      android_today = climber_ids.count do |user_id|
        profiles.dig(user_id, :primary) == DeviceFromUserAgent::DEVICE_ANDROID
      end
      play_count = User.excluding_privileged.where.not(play_app_seen_at: nil).count

      {
        android_climbed_today: android_today,
        play_app_testers: play_count
      }
    end

    def counts_by_day(month:)
      month_start = month.to_date.beginning_of_month
      month_end = month_start.end_of_month
      zone = Time.find_zone!(DAY_ZONE)
      range_start = zone.local(month_start.year, month_start.month, month_start.day).beginning_of_day
      range_end = zone.local(month_end.year, month_end.month, month_end.day).end_of_day

      privileged_ids = User.privileged.pluck(:id).to_set
      buckets = Hash.new { |hash, date| hash[date] = { testers: Set.new, admins: Set.new } }

      one_shot_battles_scope
        .where(completed_at: range_start..range_end)
        .pluck(:user_id, :completed_at)
        .each do |user_id, completed_at|
          date = completed_at.in_time_zone(zone).to_date
          next if date < month_start || date > month_end

          key = privileged_ids.include?(user_id) ? :admins : :testers
          buckets[date][key] << user_id
        end

      recurring_todos_scope
        .where(scheduled_on: month_start..month_end)
        .pluck(:user_id, :scheduled_on)
        .each do |user_id, scheduled_on|
          date = scheduled_on.to_date
          next if date < month_start || date > month_end

          key = privileged_ids.include?(user_id) ? :admins : :testers
          buckets[date][key] << user_id
        end

      result = {}
      month_start.upto(month_end) do |date|
        bucket = buckets[date]
        result[date] = { testers: bucket[:testers].size, admins: bucket[:admins].size }
      end
      result
    end

    private

    def one_shot_battles_scope
      StrategyGoal.battles
        .where.not(repeat: RECURRING_REPEATS)
        .where.not(completed_at: nil)
    end

    def recurring_todos_scope
      DailyTodo.where.not(completed_at: nil)
        .joins(:strategy_goal)
        .where(strategy_goals: { repeat: RECURRING_REPEATS })
    end

    def build_rows
      users = User.excluding_privileged.order(:id).to_a
      return [] if users.empty?

      user_ids = users.map(&:id)
      contacts = TesterContact.where(user_id: user_ids).index_by(&:user_id)
      device_profiles = device_profiles_for(user_ids)
      first_wins = merge_times(
        one_shot_battles(user_ids).group(:user_id).minimum(:completed_at),
        recurring_todos(user_ids).group(:user_id).minimum(:completed_at),
        :min
      )
      last_wins = merge_times(
        one_shot_battles(user_ids).group(:user_id).maximum(:completed_at),
        recurring_todos(user_ids).group(:user_id).maximum(:completed_at),
        :max
      )
      week_wins = merge_counts(
        one_shot_battles(user_ids).where(completed_at: week_range).group(:user_id).count,
        recurring_todos(user_ids).where(completed_at: week_range).group(:user_id).count
      )
      push_statuses = push_statuses_by_user(user_ids)
      partner_ids = partner_user_ids(user_ids)

      users.map do |user|
        profile = device_profiles[user.id] || { primary: nil, devices: [] }
        first_win_at = first_wins[user.id]
        last_win_at = last_wins[user.id]
        days_since_last_win = days_since(last_win_at&.to_date)
        push_status = push_statuses[user.id] || :off
        reason_key = reason_key_for(
          onboarding_done: user.onboarding_completed_at.present?,
          last_win_at: last_win_at,
          days_since_last_win: days_since_last_win,
          push_status: push_status
        )

        Row.new(
          user: user,
          contact: contacts[user.id],
          signed_up_at: user.created_at,
          onboarding_done: user.onboarding_completed_at.present?,
          first_win_at: first_win_at,
          last_win_at: last_win_at,
          wins_this_week: week_wins[user.id].to_i,
          last_opened_on: user.last_opened_on,
          days_since_open: days_since(user.last_opened_on),
          push_status: push_status,
          partner: partner_ids.include?(user.id),
          reason_key: reason_key,
          reason: reason_label(reason_key, days_since_last_win),
          days_since_last_win: days_since_last_win,
          primary_device: profile[:primary],
          devices: profile[:devices]
        )
      end
    end

    def device_profiles_for(user_ids)
      return {} if user_ids.blank?

      latest_session = {}
      device_sets = Hash.new { |hash, key| hash[key] = Set.new }

      Session.where(user_id: user_ids)
        .where.not(user_agent: [ nil, "" ])
        .pluck(:user_id, :user_agent, :updated_at)
        .each do |user_id, user_agent, updated_at|
          device = DeviceFromUserAgent.call(user_agent)
          device_sets[user_id] << device if device.present?

          current = latest_session[user_id]
          next if current.present? && updated_at <= current[:updated_at]

          latest_session[user_id] = { user_agent: user_agent, updated_at: updated_at }
        end

      latest_push = {}
      PushSubscription.where(user_id: user_ids)
        .where.not(user_agent: [ nil, "" ])
        .pluck(:user_id, :user_agent, :updated_at)
        .each do |user_id, user_agent, updated_at|
          device = DeviceFromUserAgent.call(user_agent)
          next if device.blank?

          device_sets[user_id] << device

          current = latest_push[user_id]
          next if current.present? && updated_at <= current[:updated_at]

          latest_push[user_id] = { user_agent: user_agent, updated_at: updated_at }
        end

      profiles = {}
      user_ids.each do |user_id|
        primary = if latest_session[user_id]
          DeviceFromUserAgent.call(latest_session[user_id][:user_agent])
        elsif latest_push[user_id]
          DeviceFromUserAgent.call(latest_push[user_id][:user_agent])
        end
        devices = DEVICE_ORDER.select { |device| device_sets[user_id].include?(device) }
        profiles[user_id] = {
          primary: primary,
          devices: devices
        }
      end
      profiles
    end

    def tester_climber_ids_for_day(date)
      zone = Time.find_zone!(DAY_ZONE)
      privileged_ids = User.privileged.pluck(:id).to_set
      ids = Set.new
      range_start = zone.local(date.year, date.month, date.day).beginning_of_day
      range_end = zone.local(date.year, date.month, date.day).end_of_day

      one_shot_battles_scope.where(completed_at: range_start..range_end).pluck(:user_id).each do |user_id|
        next if privileged_ids.include?(user_id)

        ids << user_id
      end

      recurring_todos_scope.where(scheduled_on: date).pluck(:user_id).each do |user_id|
        next if privileged_ids.include?(user_id)

        ids << user_id
      end
      ids
    end

    def matches_device_filter?(row)
      case @device
      when DEVICE_FILTER_ANDROID
        row.primary_device == DeviceFromUserAgent::DEVICE_ANDROID
      when DEVICE_FILTER_IPHONE
        row.primary_device == DeviceFromUserAgent::DEVICE_IPHONE
      when DEVICE_FILTER_COMPUTER
        row.primary_device == DeviceFromUserAgent::DEVICE_COMPUTER
      when DEVICE_FILTER_PLAY
        row.user.play_app_seen_at.present?
      else
        true
      end
    end

    def needs_message?(row)
      return false if row.reason_key.blank?

      contact = row.contact
      return true if contact.nil?

      !contact.contacted_recently?
    end

    def one_shot_battles(user_ids)
      StrategyGoal.battles
        .where(user_id: user_ids)
        .where.not(repeat: RECURRING_REPEATS)
        .where.not(completed_at: nil)
    end

    def recurring_todos(user_ids)
      DailyTodo.where(user_id: user_ids)
        .where.not(completed_at: nil)
        .joins(:strategy_goal)
        .where(strategy_goals: { repeat: RECURRING_REPEATS })
    end

    def week_range
      start = Time.current.beginning_of_week(:monday)
      finish = start.end_of_week(:monday)
      start..finish
    end

    def merge_times(left, right, mode)
      merged = {}
      [ left, right ].each do |rows|
        rows.each do |user_id, timestamp|
          next if timestamp.blank?

          merged[user_id] =
            if merged[user_id].blank?
              timestamp
            elsif mode == :min
              [ merged[user_id], timestamp ].min
            else
              [ merged[user_id], timestamp ].max
            end
        end
      end
      merged
    end

    def merge_counts(left, right)
      merged = Hash.new(0)
      left.each { |user_id, count| merged[user_id] += count.to_i }
      right.each { |user_id, count| merged[user_id] += count.to_i }
      merged
    end

    def partner_user_ids(user_ids)
      rows = ClimbPartnership.active
        .where(inviter_id: user_ids)
        .or(ClimbPartnership.active.where(invitee_id: user_ids))
        .pluck(:inviter_id, :invitee_id)

      ids = Set.new
      rows.each do |inviter_id, invitee_id|
        ids << inviter_id if user_ids.include?(inviter_id)
        ids << invitee_id if invitee_id.present? && user_ids.include?(invitee_id)
      end
      ids
    end

    # One query: user_id + delivery stamps. Status folded in Ruby.
    def push_statuses_by_user(user_ids)
      rows = PushSubscription.where(user_id: user_ids)
        .pluck(:user_id, :last_success_at, :last_error_at)
      by_user = Hash.new { |hash, key| hash[key] = [] }
      rows.each { |user_id, success_at, error_at| by_user[user_id] << [ success_at, error_at ] }

      statuses = {}
      user_ids.each do |user_id|
        statuses[user_id] = push_status_for(by_user[user_id])
      end
      statuses
    end

    def push_status_for(subscriptions)
      return :off if subscriptions.blank?

      cutoff = Time.current - PUSH_OK_WITHIN
      ok = subscriptions.any? do |success_at, error_at|
        next false if success_at.blank? || success_at < cutoff
        next true if error_at.blank?

        error_at <= success_at
      end
      ok ? :ok : :broken
    end

    def days_since(date)
      return nil if date.blank?

      (Date.current - date).to_i
    end

    def reason_key_for(onboarding_done:, last_win_at:, days_since_last_win:, push_status:)
      return :onboarding unless onboarding_done
      return :never_won if last_win_at.blank?
      return :stale if days_since_last_win.to_i >= STALE_AFTER_DAYS
      return :push_broken if push_status == :broken

      nil
    end

    def reason_label(reason_key, days_since_last_win)
      case reason_key
      when :onboarding
        I18n.t("admin.testers.reason.onboarding")
      when :never_won
        I18n.t("admin.testers.reason.never_won")
      when :stale
        I18n.t("admin.testers.reason.stale", count: days_since_last_win.to_i)
      when :push_broken
        I18n.t("admin.testers.reason.push_broken")
      end
    end

    def sort_rows(rows)
      rows.sort_by do |row|
        rank = reason_rank(row.reason_key)
        stale_days = row.days_since_last_win.to_i
        last_win_sort = row.last_win_at ? -row.last_win_at.to_i : 0
        [
          rank,
          (rank == 2 ? -stale_days : 0),
          (rank >= 3 ? last_win_sort : 0),
          -row.signed_up_at.to_i,
          row.user.id
        ]
      end
    end

    def reason_rank(reason_key)
      case reason_key
      when :onboarding then 0
      when :never_won then 1
      when :stale then 2
      when :push_broken then 3
      else 4
      end
    end
  end
end
