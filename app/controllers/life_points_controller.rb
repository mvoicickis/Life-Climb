class LifePointsController < ApplicationController
  def show
    @total = current_user.life_points
    @products_count = current_user.finished_products.count
    @buildings_shipped = current_user.buildings.shipped.count
    @days_invested = current_user.days_invested
    @years = years_building
    @ledger = current_user.life_point_ledgers.newest_first.limit(20)
    @dream = current_user.active_dream
    @goals = current_user.goals.includes(:dream, :steps).ordered
    @learning_hours = learning_hours_estimate
  end

  private

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
