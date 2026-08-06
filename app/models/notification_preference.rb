# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  FREQUENCIES = %w[often sometimes rarely off].freeze
  INTENSITIES = %w[gentle normal persistent].freeze

  belongs_to :user

  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :intensity, inclusion: { in: INTENSITIES }
  validates :quiet_hours_start, :quiet_hours_end,
            numericality: { only_integer: true, in: 0..23 },
            allow_nil: true
  validate :time_zone_must_be_valid

  def vacation_active?
    vacation_paused? || (vacation_until.present? && vacation_until >= Date.current)
  end

  private

  def time_zone_must_be_valid
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, :invalid)
  end
end
