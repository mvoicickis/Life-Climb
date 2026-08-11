# frozen_string_literal: true

class LifePointsController < ApplicationController
  def show
    if current_user.planning_v2?
      show_journey
    else
      show_legacy
    end
  end

  private

  def show_journey
    period = params[:period].presence || "7d"
    @progress = Progress::Dashboard.call(user: current_user, period: period)

    if turbo_frame_request?
      render partial: "life_points/progress_activity", locals: { progress: @progress }
      return
    end

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
    @action_points = current_user.action_points
    @strategy_points = current_user.strategy_points
    @mountain_summary = @progress[:mountain_summary]
    @journey_trends =
      if @journey
        Progress::JourneyTrends.call(user: current_user, journey: @journey)
      end
    @pattern_findings = Patterns::Detector.call(user: current_user)
    load_journey_stats
    render "life_points/progress"
  end

  def load_journey_stats
    @stats_areas = current_user.areas.ordered.includes(:habits)
    @stats_unfiled = current_user.habits.active.unfiled.visible_on_dashboard.ordered.to_a
    visible = []
    @stats_areas.each do |area|
      visible.concat(
        area.habits.select { |habit| habit.active? && !habit.hidden_from_dashboard? }
                  .sort_by { |habit| [ habit.position, habit.name.to_s ] }
      )
    end
    visible.concat(@stats_unfiled)
    @stats_series = visible.map do |habit|
      {
        habit_id: habit.id,
        title: habit.name,
        unit: habit.unit.to_s,
        days: habit.dashboard_chart_series(days: 14)
      }
    end
    @show_journey_stats = @stats_areas.any? || @stats_unfiled.any?
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
