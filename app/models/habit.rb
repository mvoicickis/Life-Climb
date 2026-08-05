class Habit < ApplicationRecord
  FREQUENCIES = %w[daily weekly].freeze
  UNIT_IDEAS = %w[times steps minutes pages words glasses hours money km litres liters].freeze
  # Units that naturally use fractions in the log input (everything else is whole-number).
  # Free-text units are matched by token (e.g. "km run", "hours slept", "€ spent").
  DECIMAL_QUANTITY_UNITS = %w[
    money hour hours km kilometer kilometers kilometre kilometres
    litre litres liter liters
  ].freeze
  DECIMAL_QUANTITY_SYMBOLS = %w[€ $ £ ¥].freeze
  # Stored keys; UI labels come from I18n (habits.growth_title / habits.range_title)
  STAT_TYPES = %w[growth standard].freeze

  belongs_to :user
  belongs_to :life_journey, optional: true
  has_many :completions, dependent: :destroy
  has_many :daily_logs, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :identity_label, length: { maximum: 120 }, allow_nil: true
  validates :points, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :description, length: { maximum: 2_000 }, allow_nil: true
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :unit, presence: true, length: { maximum: 40 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :stat_type, inclusion: { in: STAT_TYPES }
  validates :goal, numericality: { greater_than: 0 }, allow_nil: true
  validates :min_value, numericality: true, allow_nil: true
  validates :max_value, numericality: true, allow_nil: true
  validate :healthy_range_bounds
  validate :max_not_below_min
  validate :life_journey_belongs_to_user

  before_validation :normalize_unit
  before_validation :normalize_stat_fields
  before_validation :normalize_identity_label
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

  # Today UX: quantity loggers (pages/steps/hours/goals) vs one-tap checkbox dailies.
  def quantity_checkin?
    standard? || goal.present? || !%w[times].include?(unit.to_s.downcase)
  end

  def binary_checkin?
    !quantity_checkin?
  end

  # Log inputs: steps/pages/messages stay integers; money/km/hours keep decimals.
  def decimal_quantity_unit?
    key = unit.to_s.downcase.strip
    return true if DECIMAL_QUANTITY_UNITS.include?(key)
    return true if DECIMAL_QUANTITY_SYMBOLS.include?(key)

    tokens = key.scan(/[a-z]+|[€$£¥]/)
    tokens.any? { |token| DECIMAL_QUANTITY_UNITS.include?(token) || DECIMAL_QUANTITY_SYMBOLS.include?(token) }
  end

  def quantity_input_step
    decimal_quantity_unit? ? :any : 1
  end

  def quantity_inputmode
    decimal_quantity_unit? ? "decimal" : "numeric"
  end

  def better_than_yesterday?
    growth?
  end

  def healthy_range?
    standard?
  end

  def evaluation_label
    healthy_range? ? I18n.t("habits.range_title") : I18n.t("habits.growth_title")
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

  def status
    HabitStatusEvaluator.new(self).call
  end
  alias vs_yesterday status

  def status_label
    HabitStatusEvaluator.new(self).label
  end
  alias vs_yesterday_label status_label

  def range_summary
    return nil unless healthy_range?

    if min_value.present? && max_value.present?
      "#{format_bound(min_value)}–#{format_bound(max_value)}"
    elsif min_value.present?
      "#{format_bound(min_value)}+"
    elsif max_value.present?
      "up to #{format_bound(max_value)}"
    end
  end

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

  def format_bound(value)
    value == value.to_i ? value.to_i.to_s : value.to_s("F")
  end

  def normalize_unit
    self.unit = unit.to_s.strip.downcase.presence || "times"
  end

  def normalize_identity_label
    self.identity_label = identity_label.to_s.strip.presence
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

  def healthy_range_bounds
    return unless standard?
    return if min_value.present? || max_value.present?

    errors.add(:base, "Healthy Range needs a minimum, a maximum, or both")
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

  def life_journey_belongs_to_user
    return if life_journey_id.blank?
    return if user&.life_journeys&.exists?(id: life_journey_id)

    errors.add(:life_journey_id, :invalid)
  end
end
