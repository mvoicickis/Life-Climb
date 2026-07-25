# frozen_string_literal: true

class GapSnapshot < ApplicationRecord
  belongs_to :life_journey

  validates :recorded_on, presence: true, uniqueness: { scope: :life_journey_id }
  validates :gap_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
