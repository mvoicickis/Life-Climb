class Step < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :goal
  has_many :buildings, dependent: :destroy

  validates :title, presence: true, length: { maximum: TITLE_MAX }

  scope :ordered, -> { order(:position, :id) }
  scope :open, -> { where.not(status: "done") }
end
