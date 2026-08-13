# frozen_string_literal: true

# High-water overshoot bonus for one user on one calendar day.
# Ledger deltas are append-only; this row tracks peak % and total AP granted.
class DayOvershootBonus < ApplicationRecord
  self.table_name = "day_overshoot_bonuses"

  belongs_to :user
  has_many :life_point_ledgers, as: :source, dependent: :nullify

  validates :on_date, presence: true
  validates :peak_percent, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :awarded_ap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :on_date, uniqueness: { scope: :user_id }

  scope :for_day, ->(date = Date.current) { where(on_date: date) }
end
