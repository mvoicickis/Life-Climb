class Habit < ApplicationRecord
  FREQUENCIES = %w[daily weekly].freeze
  UNIT_IDEAS = %w[times steps minutes pages words glasses hours money km].freeze
  STAT_TYPES = %w[growth standard].freeze
  LEVEL_DECAY_DAYS = 3

  belongs_to :user
  has_many :completions, dependent: :destroy
  has_many :daily_logs, dependent: :destroy

  validates :name, presence: true
  validates :points, numericality: { only_integer: true, greater_than: 0 }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :unit, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :stat_type, inclusion: { in: STAT_TYPES }
  validates :goal, numericality: { greater_than: 0 }, allow_nil: true
  validates :min_value, numericality: true, allow_nil: true
  validates :max_value, numericality: true, allow_nil: true
  validate :standard_range_values
  validate :max_not_below_min

  before_validation :normalize_unit
  before_validation :normalize_stat_fields
  before_create :assign_next_position

  scope :active, -> { where(active: true) }
  scope :on_home, -> { where(show_on_home: true) }
  scope :ordered, -> { order(:position, :name) }

  def growth?
    stat_type == "growth"
  end

  def standard?
    stat_type == "standard"
  end

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
    return goal if growth? && goal.present?

    self.class.goal_from_yesterday(yesterday_amount)
  end

  # Single entry point for card color/state (type-aware).
  def status
    growth? ? growth_status : standard_status
  end
  alias vs_yesterday status

  def status_label
    if growth? && status == :down && raw_growth_comparison(Date.current) == :level
      return "Same for #{LEVEL_DECAY_DAYS}+ days — counts as Down"
    end

    case status
    when :up then "More than yesterday"
    when :level then "Same as yesterday"
    when :down then "Less than yesterday"
    when :ok then "In your range"
    when :off then "Outside your range"
    else "—"
    end
  end
  alias vs_yesterday_label status_label

  def todays_goal_value
    return goal if growth? && goal.present?

    today_log&.goal || suggested_goal_for_today
  end

  def goal_progress_percent
    return 0 unless growth?

    target = todays_goal_value
    return 0 if target.blank? || target <= 0

    [ ((today_amount / target) * 100).round, 100 ].min
  end

  def met_habit_goal?
    growth? && goal.present? && today_amount >= goal
  end

  def show_goal_raise_prompt?
    met_habit_goal? && goal_raise_declined_on != Date.current
  end

  def raise_goal!
    return false unless growth? && goal.present?

    bump = [ (goal * BigDecimal("0.01")).ceil, 1 ].max
    update!(goal: goal + bump, goal_raise_declined_on: nil)
  end

  def decline_goal_raise!
    update!(goal_raise_declined_on: Date.current)
  end

  def self.goal_from_yesterday(yesterday_amount)
    amount = yesterday_amount.nil? ? BigDecimal("0") : BigDecimal(yesterday_amount.to_s)
    return BigDecimal("1") if amount <= 0

    increase = [ (amount * BigDecimal("0.01")).ceil, 1 ].max
    amount + increase
  end

  private

  def growth_status
    raw = raw_growth_comparison(Date.current)
    if raw == :level && consecutive_raw_level_days(Date.current) >= LEVEL_DECAY_DAYS
      :down
    else
      raw
    end
  end

  def standard_status
    amount = today_amount
    return :off if min_value.blank?
    return :off if amount < min_value
    return :off if max_value.present? && amount > max_value

    :ok
  end

  def raw_growth_comparison(date)
    today = amount_or_zero(date)
    yesterday = amount_or_zero(date - 1)

    if today > yesterday
      :up
    elsif today == yesterday
      :level
    else
      :down
    end
  end

  # Counts consecutive days ending on `date` whose raw vs-yesterday is Level.
  # Stops at unlogged empty stretches so new stats don't instantly decay.
  def consecutive_raw_level_days(date)
    count = 0
    cursor = date

    while raw_growth_comparison(cursor) == :level
      if count.positive? && log_for(cursor).blank? && log_for(cursor - 1).blank?
        break
      end

      count += 1
      cursor -= 1
      break if count > 60
    end

    count
  end

  def normalize_unit
    self.unit = unit.to_s.strip.downcase.presence || "times"
  end

  def normalize_stat_fields
    self.stat_type = stat_type.to_s.presence || "growth"
    self.goal = nil if goal.blank?
    self.min_value = nil if min_value.blank?
    self.max_value = nil if max_value.blank?

    if growth?
      self.min_value = nil
      self.max_value = nil
    else
      self.goal = nil
      self.goal_raise_declined_on = nil
    end
  end

  def standard_range_values
    return unless standard?

    errors.add(:min_value, "is required for standard stats") if min_value.blank?
  end

  def max_not_below_min
    return if min_value.blank? || max_value.blank?
    return if max_value >= min_value

    errors.add(:max_value, "must be at least the minimum")
  end

  def assign_next_position
    return if position.present? && position > 0

    max_position = user&.habits&.maximum(:position) || 0
    self.position = max_position + 1
  end
end
