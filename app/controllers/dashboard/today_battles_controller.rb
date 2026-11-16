# frozen_string_literal: true

module Dashboard
  # Photo Today — inline add row creates a day battle in the current camp.
  class TodayBattlesController < ApplicationController
    include Dashboard::TodaySurface

    class DayFull < StandardError; end

    def create
      title = params[:title].to_s.strip
      if title.blank?
        log_failure("blank_title")
        return head :unprocessable_entity
      end

      if title.length > StrategyGoal::TITLE_MAX
        title = title.truncate(StrategyGoal::TITLE_MAX, omission: "")
      end

      journey = current_user.primary_focused_journey
      if journey.blank?
        log_failure("need_journey")
        return head :unprocessable_entity
      end

      begin
        camp = Strategy::PathProject.ensure!(user: current_user, journey: journey, title: title)
      rescue Strategy::HoldingProject::Error => e
        log_failure("need_camp", detail: e.message)
        return head :unprocessable_entity
      end

      if camp.blank? || camp.user_id != current_user.id
        log_failure("need_camp")
        return head :unprocessable_entity
      end

      battle = nil
      todo = nil
      ActiveRecord::Base.transaction do
        position = next_day_position(camp)
        battle = current_user.strategy_goals.create!(
          life_area: camp.life_area,
          life_journey_id: camp.life_journey_id.presence || journey.id,
          parent: camp,
          horizon: "day",
          title: title,
          scheduled_on: Date.current,
          repeat: "none",
          position: position
        )
        todo = Strategy::CascadeToDaily.sync_goal!(user: current_user, goal: battle)
        raise DayFull if todo.blank?
      end

      unless todo.user_id == current_user.id
        log_failure("todo_user_mismatch", detail: "todo_id=#{todo.id}")
        return head :unprocessable_entity
      end

      @journey = journey
      assign_today_battle_surface!(reconcile: false)
      @battlefield_health = Today::BattlefieldHealth.call(
        open_count: @battle_open_count,
        total_count: @battle_total_count,
        habits: @habits,
        habits_on: habits_local_day
      )
      assign_battlefield_prompt!
      assign_end_of_day!
      @battlefield_day_ended = Today::BattlefieldDay.ended?(session)

      respond_to do |format|
        format.turbo_stream { render :create, status: :ok }
        format.html { redirect_to dashboard_path, status: :see_other }
      end
    rescue DayFull
      log_failure("day_full", detail: "max=#{GameRules::MAX_DAILY_TODOS}")
      head :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      log_failure(
        "record_invalid",
        detail: e.record.errors.full_messages.join(", ")
      )
      head :unprocessable_entity
    rescue StandardError => e
      log_failure("error", detail: "#{e.class}: #{e.message}")
      head :unprocessable_entity
    end

    private

    def next_day_position(camp)
      scope = current_user.strategy_goals.where(parent_id: camp.id, horizon: "day")
      (scope.maximum(:position) || -1) + 1
    end

    def log_failure(reason, detail: nil)
      message = "[today_battle] #{reason} user_id=#{current_user&.id}"
      message = "#{message} #{detail}" if detail.present?
      Rails.logger.info(message)
    end
  end
end
