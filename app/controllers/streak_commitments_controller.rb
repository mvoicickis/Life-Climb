# frozen_string_literal: true

class StreakCommitmentsController < ApplicationController
  before_action :reject_read_only_impersonation

  def create
    commitment = Today::StreakCommitment.for(current_user)
    days = params[:days]
    on = Battles::WinsOnLocalDate.local_today_for(current_user)

    unless commitment.commit!(days: days, on: on)
      return render json: { ok: false, error: t("dash.battlefield.win_not_saved") }, status: :unprocessable_entity
    end

    html = reminder_html_for(commitment: commitment, target_days: days.to_i)
    render json: { ok: true, html: html }
  end

  def decline
    Today::StreakCommitment.for(current_user).decline!
    head :no_content
  end

  def destroy
    Today::StreakCommitment.for(current_user).clear!
    head :no_content
  end

  private

  def reject_read_only_impersonation
    return unless read_only_impersonation?

    head :forbidden
  end

  def reminder_html_for(commitment:, target_days:)
    return "" unless commitment.reminder_eligible?

    pair = Goals::Current.call(user: current_user)
    goal_title = helpers.active_goal_title(
      strategy_goal: pair.goal,
      journey: pair.journey
    )
    battle_title = Notifications::OpenBattleTitle.for(
      user: current_user,
      on: Battles::WinsOnLocalDate.local_today_for(current_user)
    )
    battle_line =
      if battle_title.present?
        t("climb.streak_moment.today_battle", title: battle_title)
      else
        t("climb.streak_moment.today_battle_fallback")
      end

    render_to_string(
      partial: "dashboard/streak_reminder",
      formats: [ :html ],
      locals: {
        target_days: target_days,
        goal_title: goal_title.to_s,
        battle_line: battle_line
      }
    )
  end
end
