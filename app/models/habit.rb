class Habit < ApplicationRecord
  FREQUENCIES = %w[daily weekly].freeze
  UNIT_IDEAS = %w[times steps minutes pages words glasses hours money km].freeze

  belongs_to :user
  has_many :completions, dependent: :destroy
  has_many :daily_logs, dependent: :destroy

  validates :name, presence: true
  validates :points, numericality: { only_integer: true, greater_than: 0 }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :unit, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_unit
  before_create :assign_next_position

  scope :active, -> { where(active: true) }
  scope :on_home, -> { where(show_on_home: true) }
  scope :ordered, -> { order(:position, :name) }

  def completed_today?
    completions.exists?(completed_on: Date.current)
  end

  def completion_for(date)
    completions.find_by(completed_on: date)
  end

  def log_for(date)
    daily_logs.find_by(logged_on: date)
  end

  def today_log
    log_for(Date.current)
  end

  def yesterday_log
    log_for(Date.yesterday)
  end

  # Empty day slot counts as 0
  def amount_or_zero(date)
    log_for(date)&.amount || BigDecimal("0")
  end

  def today_amount
    amount_or_zero(Date.current)
  end

  def yesterday_amount
    amount_or_zero(Date.yesterday)
  end

  def logged_on?(date)
    log_for(date).present?
  end

  def suggested_goal_for_today
    self.class.goal_from_yesterday(yesterday_amount)
  end

  # Only two states: green (up) or red (same or less)
  def vs_yesterday
    today_amount > yesterday_amount ? :up : :not_up
  end

  def vs_yesterday_label
    if today_amount > yesterday_amount
      "More than yesterday"
    elsif today_amount == yesterday_amount
      "Same as yesterday"
    else
      "Less than yesterday"
    end
  end

  def todays_goal_value
    today_log&.goal || suggested_goal_for_today
  end

  def goal_progress_percent
    goal = todays_goal_value
    return 0 if goal.blank? || goal <= 0

    [ ((today_amount / goal) * 100).round, 100 ].min
  end

  def self.goal_from_yesterday(yesterday_amount)
    amount = yesterday_amount.nil? ? BigDecimal("0") : BigDecimal(yesterday_amount.to_s)
    return BigDecimal("1") if amount <= 0

    increase = [ (amount * BigDecimal("0.01")).ceil, 1 ].max
    amount + increase
  end

  private

  def normalize_unit
    self.unit = unit.to_s.strip.downcase.presence || "times"
  end

  def assign_next_position
    return if position.present? && position > 0

    max_position = user&.habits&.maximum(:position) || 0
    self.position = max_position + 1
  end
end
