class FinishedProduct < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :building, optional: true
  belongs_to :goal, optional: true

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :value_summary, length: { maximum: SUMMARY_MAX }, allow_nil: true
  validates :shipped_on, presence: true

  scope :newest_first, -> { order(shipped_on: :desc, id: :desc) }
end
