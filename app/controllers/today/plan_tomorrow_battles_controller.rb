# frozen_string_literal: true

module Today
  # Creates a tomorrow (or today) battle from the end-of-day planning step.
  class PlanTomorrowBattlesController < ApplicationController
    def create
      project = current_user.strategy_goals.find_by(id: params[:project_id])
      unless project&.project? && project.completed_at.blank? && !project.holding?
        redirect_to dashboard_path, alert: t("dash.end_of_day.invalid_camp"), status: :see_other
        return
      end

      title = params.require(:title).to_s.strip
      if title.blank?
        redirect_to dashboard_path, alert: t("dash.end_of_day.need_title"), status: :see_other
        return
      end

      for_today = params[:schedule].to_s == "today"
      scheduled_on = for_today ? Date.current : Date.current + 1.day
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
        celebration = Strategy::Celebrate.call(user: current_user, goal: battle)
        Strategy::CascadeToDaily.call(user: current_user, life_area: project.life_area)
        if for_today
          Today::EodFlow.reset_acknowledge!(session)
          redirect_to dashboard_path,
                      notice: t("dash.end_of_day.saved_today", title: title),
                      status: :see_other
        else
          redirect_to dashboard_path,
                      notice: t("dash.end_of_day.saved",
                        title: title,
                        count: celebration[:amount].to_i),
                      status: :see_other
        end
      else
        redirect_to dashboard_path,
                    alert: battle.errors.full_messages.to_sentence,
                    status: :see_other
      end
    end

    private

    def next_position(parent, scheduled_on:)
      current_user.strategy_goals
        .where(parent_id: parent.id, horizon: "day", scheduled_on: scheduled_on)
        .maximum(:position).to_i + 1
    end
  end
end
