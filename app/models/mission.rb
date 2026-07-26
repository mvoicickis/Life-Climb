# frozen_string_literal: true

class Mission < ApplicationRecord
  include TextLimits

  STATUSES = %w[pending complete replaced skipped].freeze
  SOURCES = %w[system user ai].freeze

  belongs_to :user
  belongs_to :life_journey

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :scheduled_on, presence: true
  validates :lp_reward, numericality: { only_integer: true, greater_than: 0 }
  validates :gap_delta_basis_points, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :aspect_key, inclusion: { in: LifeArea::CATALOG_KEYS }, allow_blank: true
  validate :user_matches_journey

  before_validation :sync_user_from_journey, on: :create

  scope :for_day, ->(date = Date.current) { where(scheduled_on: date) }
  scope :incomplete, -> { where(status: "pending", completed_at: nil) }
  scope :complete, -> { where.not(completed_at: nil) }
  scope :primary, -> { where(is_primary: true) }
  scope :ordered, -> { order(:position, :id) }

  def completed?
    completed_at.present? || status == "complete"
  end

  def gap_delta_percent
    (gap_delta_basis_points.to_i / 100.0).round(2)
  end

  private

  def sync_user_from_journey
    self.user_id ||= life_journey&.user_id
  end

  def user_matches_journey
    return if life_journey.blank? || user_id.blank?
    return if life_journey.user_id == user_id

    errors.add(:life_journey, "must belong to the same user")
  end
end
