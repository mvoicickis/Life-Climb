class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :completions, dependent: :destroy
  has_many :daily_logs, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :home_stat_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 20
  }

  def points_today
    completions.where(completed_on: Date.current).sum(:points_awarded)
  end

  def home_trackers
    habits.active.on_home.ordered.limit(home_stat_count)
  end

  def home_board_habits
    habits.active.on_home.ordered
  end
end
