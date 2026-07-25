class Goal < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :dream
  belongs_to :life_area, optional: true
  has_many :steps, -> { order(:position, :id) }, dependent: :destroy
  has_many :finished_products, dependent: :nullify

  validates :title, presence: true, length: { maximum: TITLE_MAX }

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:position, :id) }
end
