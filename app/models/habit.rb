class Habit < ApplicationRecord
  FREQUENCIES = %w[daily weekly].freeze

  belongs_to :user
  has_many :completions, dependent: :destroy

  validates :name, presence: true
  validates :points, numericality: { only_integer: true, greater_than: 0 }
  validates :frequency, inclusion: { in: FREQUENCIES }

  scope :active, -> { where(active: true) }

  def completed_today?
    completions.exists?(completed_on: Date.current)
  end

  def completion_for(date)
    completions.find_by(completed_on: date)
  end
end
