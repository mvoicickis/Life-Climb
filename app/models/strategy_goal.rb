# frozen_string_literal: true

class StrategyGoal < ApplicationRecord
  include TextLimits

  HORIZONS = %w[year month week day].freeze
  CHILD_HORIZON = {
    "year" => "month",
    "month" => "week",
    "week" => "day"
  }.freeze

  belongs_to :user
  belongs_to :life_area
  belongs_to :life_journey, optional: true
  belongs_to :parent, class_name: "StrategyGoal", optional: true
  has_many :children, class_name: "StrategyGoal", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :daily_todos, dependent: :nullify

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :horizon, presence: true, inclusion: { in: HORIZONS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :scheduled_on_required_for_day
  validate :due_on_rules
  validate :parent_horizon_matches
  validate :child_fits_parent_window

  before_validation :assign_year_due_on, if: -> { horizon == "year" }

  scope :ordered, -> { order(:position, :id) }
  scope :for_horizon, ->(horizon) { where(horizon: horizon) }
  scope :for_area, ->(area_id) { where(life_area_id: area_id) }
  scope :roots, -> { where(parent_id: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :for_day, ->(date = Date.current) { where(horizon: "day", scheduled_on: date) }

  def completed?
    completed_at.present?
  end

  def child_horizon
    CHILD_HORIZON[horizon]
  end

  def aspect_key
    key = life_area&.key.to_s
    return key if LifeArea::HOME_ASPECT_KEYS.include?(key)

    "self"
  end

  def overdue?
    return false if completed?
    marker = horizon == "day" ? scheduled_on : due_on
    marker.present? && marker < Date.current
  end

  def time_marker
    horizon == "day" ? scheduled_on : due_on
  end

  private

  def assign_year_due_on
    self.due_on = Strategy::YearCycle.target_dec29
  end

  def scheduled_on_required_for_day
    return unless horizon == "day"
    return if scheduled_on.present?

    errors.add(:scheduled_on, :blank)
  end

  def due_on_rules
    case horizon
    when "year"
      errors.add(:due_on, :blank) if due_on.blank?
      errors.add(:due_on, :invalid) if due_on.present? && !Strategy::YearCycle.dec29?(due_on)
    when "month", "week"
      errors.add(:due_on, :blank) if due_on.blank?
    end
  end

  def parent_horizon_matches
    return if parent.blank?
    return if CHILD_HORIZON[parent.horizon] == horizon

    errors.add(:parent_id, :invalid)
  end

  def child_fits_parent_window
    return if parent.blank?

    child_date = horizon == "day" ? scheduled_on : due_on
    parent_due = parent.due_on
    return if child_date.blank? || parent_due.blank?
    return if child_date <= parent_due

    errors.add(:due_on, :invalid)
  end
end
