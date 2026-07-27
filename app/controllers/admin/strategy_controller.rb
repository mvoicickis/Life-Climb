# frozen_string_literal: true

module Admin
  # Browser tester for Phase 1 AI strategist (admin-only). Never writes user data.
  class StrategyController < BaseController
    def show
      @goal = params[:goal].to_s
      @current_reality = params[:current_reality].to_s
      @ideal_scene = params[:ideal_scene].to_s
      @life_area = params[:life_area].to_s
      @result = nil
      @error = nil
    end

    def create
      @goal = params[:goal].to_s.strip
      @current_reality = params[:current_reality].to_s.strip
      @ideal_scene = params[:ideal_scene].to_s.strip
      @life_area = params[:life_area].to_s.strip

      if @goal.blank?
        @error = t("admin.strategy.goal_required")
        @result = nil
        render :show, status: :unprocessable_entity
        return
      end

      context = {
        current_reality: @current_reality.presence,
        ideal_scene: @ideal_scene.presence,
        life_area: @life_area.presence
      }.compact

      @result = Ai::StrategyService.call(goal: @goal, context:)
      @error = nil
      render :show
    rescue Ai::Error => e
      @result = nil
      @error = e.message
      render :show, status: :unprocessable_entity
    end
  end
end
