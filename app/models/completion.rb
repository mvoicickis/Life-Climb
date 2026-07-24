class Completion < ApplicationRecord
  belongs_to :user
  belongs_to :habit

  validates :completed_on, presence: true
  validates :points_awarded, numericality: { only_integer: true, greater_than: 0 }
  validates :habit_id, uniqueness: { scope: :completed_on, message: "already completed for this day" }

  before_validation :set_points_awarded, on: :create

  after_create :increment_user_points
  after_destroy :decrement_user_points

  private

  def set_points_awarded
    self.points_awarded ||= habit.points
  end

  def increment_user_points
    user.increment!(:total_points, points_awarded)
  end

  def decrement_user_points
    user.decrement!(:total_points, points_awarded)
  end
end
