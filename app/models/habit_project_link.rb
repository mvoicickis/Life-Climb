# frozen_string_literal: true

class HabitProjectLink < ApplicationRecord
  belongs_to :habit
  belongs_to :strategy_goal

  validates :habit_id, uniqueness: { scope: :strategy_goal_id }
  validate :strategy_goal_must_be_path_project
  validate :habit_belongs_to_project_user

  private

  def strategy_goal_must_be_path_project
    return if strategy_goal.blank?
    return if strategy_goal.path_level_camp?

    errors.add(:strategy_goal_id, :invalid)
  end

  def habit_belongs_to_project_user
    return if habit.blank? || strategy_goal.blank?
    return if habit.user_id == strategy_goal.user_id

    errors.add(:habit_id, :invalid)
  end
end
