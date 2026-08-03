# frozen_string_literal: true

# Checklist objectives inside a Practice (day StrategyGoal) quest folder.
class PracticeTask < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :strategy_goal
  has_one :strategy_quantity_log, dependent: :nullify

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :practice_must_be_day
  validate :track_quantity_requires_quantified_ancestor

  before_validation :assign_defaults
  before_validation :normalize_track_quantity

  scope :ordered, -> { order(:position, :id) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :complete, -> { where.not(completed_at: nil) }

  def completed?
    completed_at.present?
  end

  def complete!
    update!(completed_at: Time.current) if completed_at.blank?
  end

  def reopen!
    update!(completed_at: nil) if completed_at.present?
  end

  # Soft opt-in AND hard gate: only ask for amounts under a quantified path project.
  def tracks_quantity?
    track_quantity? && strategy_goal&.quantified_path_project.present?
  end

  private

  def assign_defaults
    self.position = 0 if position.nil?
    self.user_id ||= strategy_goal&.user_id
  end

  def normalize_track_quantity
    self.track_quantity = false if strategy_goal&.quantified_path_project.blank?
  end

  def track_quantity_requires_quantified_ancestor
    return unless track_quantity?
    return if strategy_goal&.quantified_path_project.present?

    errors.add(:track_quantity, :invalid)
  end

  def practice_must_be_day
    return if strategy_goal&.day?

    errors.add(:strategy_goal, :invalid)
  end
end
