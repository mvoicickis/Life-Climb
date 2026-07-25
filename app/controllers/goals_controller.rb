class GoalsController < ApplicationController
  def create
    dream = current_user.active_dream || current_user.dreams.first
    unless dream
      redirect_to onboarding_path and return
    end

    goal = current_user.goals.new(
      dream: dream,
      title: params.require(:goal).permit(:title)[:title],
      position: current_user.goals.count
    )

    if goal.save
      redirect_to life_points_path, notice: t("life_points.goal_added")
    else
      redirect_to life_points_path, alert: goal.errors.full_messages.to_sentence
    end
  end
end
