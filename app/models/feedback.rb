class Feedback < ApplicationRecord
  belongs_to :user

  validates :body, presence: true, length: { minimum: 3, maximum: 2000 }

  scope :newest_first, -> { order(created_at: :desc) }
end
