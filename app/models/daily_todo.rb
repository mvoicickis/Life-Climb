# frozen_string_literal: true

class DailyTodo < ApplicationRecord
  include TextLimits

  belongs_to :user

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :aspect_key, presence: true, inclusion: { in: LifeArea::HOME_ASPECT_KEYS }
  validates :scheduled_on, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_day, ->(date = Date.current) { where(scheduled_on: date) }
  scope :for_aspect, ->(key) { where(aspect_key: key) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  def completed?
    completed_at.present?
  end
end
