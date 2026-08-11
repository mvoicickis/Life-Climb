# frozen_string_literal: true

class PatternSnapshot < ApplicationRecord
  belongs_to :user

  validates :computed_on, presence: true, uniqueness: { scope: :user_id }
end
