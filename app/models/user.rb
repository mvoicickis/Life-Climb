class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :completions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  def points_today
    completions.where(completed_on: Date.current).sum(:points_awarded)
  end
end
