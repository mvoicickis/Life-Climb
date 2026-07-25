class Dream < ApplicationRecord
  include TextLimits

  belongs_to :user
  has_many :goals, dependent: :destroy

  validates :title, presence: true, length: { maximum: TITLE_MAX }

  scope :active, -> { where(active: true) }
end
