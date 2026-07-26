# frozen_string_literal: true

class LifeJourney < ApplicationRecord
  include TextLimits

  STATUSES = %w[draft active completed archived].freeze

  belongs_to :user
  belongs_to :life_area
  has_many :missions, dependent: :destroy
  has_many :gap_snapshots, dependent: :destroy

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :ideal_scene, presence: true, length: { maximum: SUMMARY_MAX }
  validates :current_reality, presence: true, length: { maximum: SUMMARY_MAX }
  validates :next_win, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :purpose, :policy, :approach, :program, :finished_result,
            length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :focus_position, inclusion: { in: 1..3 }, allow_nil: true
  validates :gap_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :user_matches_life_area

  before_validation :sync_user_from_area, on: :create
  before_validation :touch_scenes_revised, if: :scenes_changed?

  scope :active, -> { where(status: "active") }
  scope :focused, -> { where.not(focus_position: nil).order(:focus_position) }
  scope :primary_focus, -> { where(focus_position: 1) }

  def focused?
    focus_position.present?
  end

  def closer_percent
    (100 - gap_percent.to_f).clamp(0, 100).round(1)
  end

  def gap_yesterday
    gap_snapshots.find_by(recorded_on: Date.current - 1)&.gap_percent
  end

  def gap_delta_vs_yesterday
    yesterday = gap_yesterday
    return nil unless yesterday

    (gap_percent.to_f - yesterday.to_f).round(2)
  end

  private

  def sync_user_from_area
    self.user_id ||= life_area&.user_id
  end

  def user_matches_life_area
    return if life_area.blank? || user_id.blank?
    return if life_area.user_id == user_id

    errors.add(:life_area, "must belong to the same user")
  end

  def scenes_changed?
    ideal_scene_changed? || current_reality_changed?
  end

  def touch_scenes_revised
    self.scenes_revised_at = Time.current
  end
end
