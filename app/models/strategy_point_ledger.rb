# frozen_string_literal: true

class StrategyPointLedger < ApplicationRecord
  belongs_to :user
  belongs_to :source, polymorphic: true, optional: true

  validates :amount, presence: true
  validates :reason, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
end
