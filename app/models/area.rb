# frozen_string_literal: true

class Area < ApplicationRecord
  include TextLimits

  belongs_to :user
  has_many :habits, dependent: :nullify

  validates :name, presence: true, length: { maximum: TITLE_MAX }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_create :assign_next_position
  # prepend so this runs before dependent: :nullify empties the association.
  before_destroy :clear_filed_tracker_state, prepend: true

  scope :ordered, -> { order(:position, :id) }

  private

  def assign_next_position
    return if position.present? && position.positive?

    max_position = user&.areas&.maximum(:position) || 0
    self.position = max_position + 1
  end

  def clear_filed_tracker_state
    Habit.where(area_id: id).update_all(state: nil, updated_at: Time.current)
  end
end

