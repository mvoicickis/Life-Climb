# frozen_string_literal: true

module Today
  # Creates a tomorrow battle from the end-of-day Day won step.
  class PlanTomorrowBattlesController < ApplicationController
    def create
      journey = current_user.primary_focused_journey
      project = Today::EndOfDay.planning_project(user: current_user, journey: journey)
      unless project&.project? && project.completed_at.blank? && !project.holding?
        log_plan_failure("invalid_camp", project_id: params[:project_id])
        respond_to do |format|
          format.html do
            redirect_to dashboard_path, alert: t("dash.end_of_day.invalid_camp"), status: :see_other
          end
          format.json do
            render json: { error: t("dash.battlefield.win_not_saved") }, status: :unprocessable_entity
          end
        end
        return
      end

      title = params[:title].to_s.strip
      if title.blank?
        log_plan_failure("blank_title")
        respond_to do |format|
          format.html do
            redirect_to dashboard_path, alert: t("dash.end_of_day.need_title"), status: :see_other
          end
          format.json do
            render json: { error: t("dash.battlefield.win_not_saved") }, status: :unprocessable_entity
          end
        end
        return
      end

      scheduled_on = Date.current + 1.day
      battle = current_user.strategy_goals.new(
        life_area: project.life_area,
        life_journey_id: project.life_journey_id,
        parent: project,
        horizon: "day",
        title: title,
        scheduled_on: scheduled_on,
        position: next_position(project, scheduled_on: scheduled_on)
      )

      if battle.save
        Strategy::CascadeToDaily.call(user: current_user, life_area: project.life_area)
        Today::BattlefieldDay.end!(session)
        respond_to do |format|
          format.html { redirect_to dashboard_path, status: :see_other }
          format.json { render json: { redirect_to: dashboard_path } }
        end
      else
        log_plan_failure("validation", errors: battle.errors.full_messages)
        respond_to do |format|
          format.html do
            redirect_to dashboard_path,
                        alert: battle.errors.full_messages.to_sentence,
                        status: :see_other
          end
          format.json do
            render json: { error: t("dash.battlefield.win_not_saved") }, status: :unprocessable_entity
          end
        end
      end
    end

    private

    def next_position(parent, scheduled_on:)
      current_user.strategy_goals
        .where(parent_id: parent.id, horizon: "day", scheduled_on: scheduled_on)
        .maximum(:position).to_i + 1
    end

    def log_plan_failure(reason, **details)
      Rails.logger.warn(
        "[Today::PlanTomorrowBattles] #{reason} user=#{current_user.id} #{details.map { |k, v| "#{k}=#{v}" }.join(' ')}"
      )
    end
  end
end
