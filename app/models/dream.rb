class Dream < ApplicationRecord
  belongs_to :user
  has_many :goals, dependent: :destroy

  validates :title, presence: true

  scope :active, -> { where(active: true) }
end
