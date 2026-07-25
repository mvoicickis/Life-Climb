class Dream < ApplicationRecord
  include TextLimits

  belongs_to :user
  has_many :goals, dependent: :destroy
  has_many :life_areas, -> { order(:position, :number, :id) }, dependent: :destroy

  validates :title, presence: true, length: { maximum: TITLE_MAX }

  scope :active, -> { where(active: true) }

  def ensure_life_areas!
    LifeArea.ensure_for_dream!(self)
  end
end
