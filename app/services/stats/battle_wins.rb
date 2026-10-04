# frozen_string_literal: true

module Stats
  class BattleWins
    BEST_DAY_LOOKBACK_DAYS = 28
    BEST_DAY_MIN_WINS = 5

    def self.call(user:, journey: nil)
      new(user: user, journey: journey)
    end

    def initialize(user:, journey: nil)
      @user = user
      @journey = journey || user.primary_focused_journey
    end

    def time_zone
      Battles::WinsOnLocalDate.time_zone_for(@user)
    end

    def local_today
      Battles::WinsOnLocalDate.local_today_for(@user)
    end

    def counts_by_date(from:, to:)
      Battles::WinsOnLocalDate.counts_by_date(
        user: @user,
        from: from,
        to: to,
        time_zone: time_zone
      )
    end

    def all_time_total
      to = local_today
      from = @user.created_at.in_time_zone(time_zone).to_date
      from = to if from > to

      counts_by_date(from: from, to: to).values.sum
    end

    def this_week
      start = local_today.beginning_of_week(:monday)
      finish = start + 6
      counts = counts_by_date(from: start, to: finish)
      days = (0..6).map { |offset| start + offset }
      values = days.map { |day| counts[day].to_i }

      {
        start: start,
        days: days,
        counts: values,
        total: values.sum
      }
    end

    def by_weekday(from: nil, to: nil)
      to ||= local_today
      from ||= to - (BEST_DAY_LOOKBACK_DAYS - 1)
      counts = counts_by_date(from: from, to: to)
      totals = Array.new(7, 0)

      counts.each do |date, wins|
        next if wins.to_i <= 0

        index = (date.cwday - 1) % 7
        totals[index] += wins
      end

      totals
    end

    def best_weekday
      to = local_today
      from = to - (BEST_DAY_LOOKBACK_DAYS - 1)
      counts = counts_by_date(from: from, to: to)
      total = counts.values.sum
      return nil if total < BEST_DAY_MIN_WINS

      totals = by_weekday(from: from, to: to)
      max_index = totals.each_with_index.max_by { |value, _| value }&.last
      return nil if max_index.nil? || totals[max_index].to_i <= 0

      weekday_date = to.beginning_of_week(:monday) + max_index
      I18n.l(weekday_date, format: "%A")
    end

    def by_camp
      projects = camp_projects
      return [] if projects.empty?

      battle_map = Strategy::BattleIdsByProject.call(user: @user, journey: @journey, projects: projects)
      battle_to_project = {}
      battle_map.each do |project_id, battle_ids|
        battle_ids.each { |battle_id| battle_to_project[battle_id] = project_id }
      end

      return [] if battle_to_project.empty?

      wins_by_project = Hash.new(0)
      recurring = Battles::WinsOnLocalDate::RECURRING_REPEATS
      battle_ids = battle_to_project.keys

      @user.strategy_goals.battles
        .where(id: battle_ids)
        .where.not(repeat: recurring)
        .where.not(completed_at: nil)
        .pluck(:id)
        .each do |battle_id|
          project_id = battle_to_project[battle_id]
          wins_by_project[project_id] += 1 if project_id
        end

      base = @user.daily_todos.where(strategy_goal_id: battle_ids).where.not(completed_at: nil)
      strategy_rows = base.where.not(strategy_goal_id: nil).or(base.where(tag: "strategy"))
      strategy_rows
        .joins(:strategy_goal)
        .where(strategy_goals: { repeat: recurring })
        .pluck(:strategy_goal_id)
        .each do |battle_id|
          project_id = battle_to_project[battle_id]
          wins_by_project[project_id] += 1 if project_id
        end

      projects.filter_map do |project|
        wins = wins_by_project[project.id].to_i
        next if wins <= 0

        ancestors = project.ancestor_chain.reverse
        plan = ancestors.find { |node| node.plan? && !node.holding? }
        goal = ancestors.find { |node| node.goal? && !node.holding? }

        {
          project_id: project.id,
          title: project.title,
          wins: wins,
          plan_id: plan&.id,
          goal_id: goal&.id
        }
      end.sort_by { |row| [ -row[:wins], row[:title].to_s.downcase ] }
    end

    def calendar_month(year, month)
      month_start = Date.new(year, month, 1)
      month_end = month_start.end_of_month
      counts = counts_by_date(from: month_start, to: month_end)
      days_with_wins = counts.count { |_, wins| wins.to_i.positive? }

      {
        year: year,
        month: month,
        month_start: month_start,
        month_end: month_end,
        counts_by_day: counts,
        days_with_wins: days_with_wins
      }
    end

    def calendar_tier(wins)
      case wins.to_i
      when 0 then 0
      when 1 then 1
      when 2, 3 then 2
      else 3
      end
    end

    private

    def camp_projects
      return [] unless @journey

      @user.strategy_goals
        .where(life_journey_id: @journey.id, horizon: "project")
        .not_holding
        .includes(:parent, :children)
        .order(:position, :id)
        .select(&:path_level_camp?)
    end
  end
end
