class Step < ApplicationRecord
  belongs_to :user
  belongs_to :goal
  has_many :buildings, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(:position, :id) }
  scope :open, -> { where.not(status: "done") }
end
