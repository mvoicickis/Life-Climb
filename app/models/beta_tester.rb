# frozen_string_literal: true

class BetaTester < ApplicationRecord
  belongs_to :user, optional: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :added_at, presence: true
end
