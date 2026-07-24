class DailyLog < ApplicationRecord
  belongs_to :habit
  belongs_to :user

  validates :logged_on, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :habit_id, uniqueness: { scope: :logged_on, message: "already has a number for this day" }
  validate :habit_belongs_to_user

  before_validation :assign_user_from_habit, on: :create
  before_validation :normalize_amount
  before_validation :set_default_goal, on: :create

  def met_goal?
    goal.present? && amount >= goal
  end

  private

  def assign_user_from_habit
    self.user ||= habit&.user
  end

  def normalize_amount
    self.amount = 0 if amount.blank?
  end

  def set_default_goal
    return if goal.present?
    return if habit.blank?

    self.goal = habit.suggested_goal_for_today if logged_on == Date.current
  end

  def habit_belongs_to_user
    return if habit.blank? || user.blank?
    return if habit.user_id == user_id

    errors.add(:habit, "must be yours")
  end
end
