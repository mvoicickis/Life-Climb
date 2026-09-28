# frozen_string_literal: true

class LifePointsController < ApplicationController
  def show
    if current_user.planning_v2?
      show_journey
    else
      show_legacy
    end
  end

  def more
    unless current_user.planning_v2?
      redirect_to life_points_path
      return
    end

    @journey = current_user.primary_focused_journey
    @period = stats_more_period_param
    @charts = Stats::MoreCharts.call(user: current_user, journey: @journey)
    render "life_points/more"
  end

  private

  def stats_more_period_param
    params[:period].to_s == "daily" ? "daily" : "weekly"
  end

  def show_journey
    if turbo_frame_request? && request.headers["Turbo-Frame"] == "stats_calendar"
      load_stats_page_data!
      render partial: "life_points/stats_calendar", locals: stats_calendar_locals
      return
    end

    load_stats_page_data!
    render "life_points/progress"
  end

  def load_stats_page_data!
    @journey = current_user.primary_focused_journey
    @strategy_goal =
      if @journey
        current_user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
      end
    @closer =
      if @strategy_goal
        @strategy_goal.progress_percent.to_i
      else
        @journey&.closer_percent&.round || 0
      end
    @mountain = Strategy::Mountain.for(goal: @strategy_goal)
    @mountain_summary = Progress::Dashboard.call(user: current_user, period: "7d")[:mountain_summary]
    @mountain_progress = helpers.end_of_day_mountain_progress(@strategy_goal, @mountain)
    @battle_wins = Stats::BattleWins.call(user: current_user, journey: @journey)
    @stats_week = @battle_wins.this_week
    @stats_best_weekday = @battle_wins.best_weekday
    @stats_camps = @battle_wins.by_camp
    @stats_milestones = Stats::Milestones.call(
      user: current_user,
      battle_wins: @battle_wins,
      mountain_summary: @mountain_summary,
      strategy_goal: @strategy_goal
    )
    @stats_calendar_month = stats_calendar_month_start
    @stats_calendar = @battle_wins.calendar_month(
      @stats_calendar_month.year,
      @stats_calendar_month.month
    )
  end

  def stats_calendar_locals
    {
      battle_wins: @battle_wins,
      calendar: @stats_calendar,
      calendar_month: @stats_calendar_month,
      journey: @journey
    }
  end

  def stats_calendar_month_start
    today = Stats::BattleWins.call(user: current_user).local_today
    cap = today.beginning_of_month
    raw = params[:stats_month].presence
    return cap if raw.blank?

    year, month = raw.split("-", 2).map(&:to_i)
    date = Date.new(year, month, 1)
    date > cap ? cap : date
  rescue ArgumentError, Date::Error
    cap
  end

  def show_legacy
    @total = current_user.life_points
    @alive_level = current_user.alive_level
    @products_count = current_user.finished_products.count
    @buildings_shipped = current_user.buildings.shipped.count
    @days_invested = current_user.days_invested
    @years = years_building
    @ledger = current_user.life_point_ledgers.newest_first.limit(20)
    @dream = current_user.active_dream
    @life_areas = @dream&.ensure_life_areas!
    @goals = current_user.goals.includes(:dream, :steps, :life_area).ordered
    @learning_hours = learning_hours_estimate
    @support_moment = offer_support_moment!
    render "life_points/show"
  end

  def offer_support_moment!
    moment = SupportMoment.new(current_user)
    key = moment.eligible
    moment.mark_shown!(key) if key
    key
  end

  def years_building
    start = current_user.created_at.to_date
    days = (Date.current - start).to_i
    return 0 if days < 30

    (days / 365.0).round(1)
  end

  def learning_hours_estimate
    logs = current_user.daily_logs.joins(:habit).where("LOWER(habits.name) LIKE ?", "%learn%")
    if logs.exists?
      logs.sum(:amount).to_f.round
    else
      (current_user.days_invested * 1.5).round
    end
  end
end
