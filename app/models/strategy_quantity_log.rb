# frozen_string_literal: true

# One amount logged toward a quantified path-level project (battle or objective).
class StrategyQuantityLog < ApplicationRecord
  belongs_to :user
  belongs_to :strategy_goal
  belongs_to :source_day, class_name: "StrategyGoal", optional: true
  belongs_to :daily_todo, optional: true
  belongs_to :practice_task, optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :unit, presence: true, length: { maximum: 40 }
  validates :logged_on, presence: true
end
