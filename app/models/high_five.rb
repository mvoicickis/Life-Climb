# frozen_string_literal: true

class HighFive < ApplicationRecord
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"
  belongs_to :strategy_goal
  belongs_to :daily_todo, optional: true

  validates :from_user, :to_user, :strategy_goal, presence: true
  validate :unique_for_local_day

  # Existing cheer from +from_user+ for this battle (+ optional todo) on +on+ in +time_zone+.
  def self.exists_for_local_day?(from_user:, strategy_goal:, daily_todo:, on:, time_zone:)
    zone = Time.find_zone!(time_zone)
    range = zone.local(on.year, on.month, on.day).all_day

    scope = where(from_user_id: from_user.id, strategy_goal_id: strategy_goal.id, created_at: range)
    scope = if daily_todo
      scope.where(daily_todo_id: daily_todo.id)
    else
      scope.where(daily_todo_id: nil)
    end
    scope.exists?
  end

  private

  def unique_for_local_day
    return if from_user.blank? || to_user.blank? || strategy_goal.blank?

    zone = Battles::WinsOnLocalDate.time_zone_for(to_user)
    on = if created_at
      created_at.in_time_zone(Time.find_zone!(zone)).to_date
    else
      Battles::WinsOnLocalDate.local_today_for(to_user)
    end

    return unless self.class.exists_for_local_day?(
      from_user: from_user,
      strategy_goal: strategy_goal,
      daily_todo: daily_todo,
      on: on,
      time_zone: zone
    )

    errors.add(:base, "already high-fived this battle today")
  end
end
