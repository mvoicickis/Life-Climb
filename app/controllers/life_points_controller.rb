# frozen_string_literal: true

class LifePointsController < ApplicationController
  def show
    if current_user.planning_v2?
      show_progress
    else
      show_legacy
    end
  end

  private

  def show_progress
    period = params[:period].presence || "7d"
    @progress = Progress::Dashboard.call(user: current_user, period: period)
    render "life_points/progress"
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
