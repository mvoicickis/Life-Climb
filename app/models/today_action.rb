class TodayAction < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :building

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :scheduled_on, presence: true

  scope :for_day, ->(day) { where(scheduled_on: day) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :complete, -> { where.not(completed_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  def completed?
    completed_at.present?
  end
end
