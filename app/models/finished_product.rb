class FinishedProduct < ApplicationRecord
  belongs_to :user
  belongs_to :building, optional: true
  belongs_to :goal, optional: true

  validates :title, presence: true
  validates :shipped_on, presence: true

  scope :newest_first, -> { order(shipped_on: :desc, id: :desc) }
end
