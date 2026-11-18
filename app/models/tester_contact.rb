# frozen_string_literal: true

# Admin-only outreach info for beta testers. Never render outside Admin.
class TesterContact < ApplicationRecord
  CHANNELS = %w[whatsapp messenger email other].freeze
  DETAILS_MAX = 200
  NOTE_MAX = 200
  WHATSAPP_MIN_DIGITS = 8
  RECENT_CONTACT_DAYS = 3

  belongs_to :user
  belongs_to :updated_by, class_name: "User", optional: true

  validates :user_id, uniqueness: true
  validates :channel, inclusion: { in: CHANNELS }, allow_blank: true
  validates :details, length: { maximum: DETAILS_MAX }, allow_blank: true
  validates :note, length: { maximum: NOTE_MAX }, allow_blank: true

  before_validation :normalize_fields

  def whatsapp_digits
    digits = details.to_s.gsub(/\D/, "")
    digits = digits.sub(/\A00/, "")
    digits.presence
  end

  def whatsapp_url
    digits = whatsapp_digits
    return nil if digits.blank? || digits.length < WHATSAPP_MIN_DIGITS

    "https://wa.me/#{digits}"
  end

  def mailto_address(fallback_email: nil)
    candidate = details.to_s.strip.presence || fallback_email.to_s.strip.presence
    return nil if candidate.blank?
    return nil unless candidate.match?(URI::MailTo::EMAIL_REGEXP)

    candidate
  end

  def mailto_url(fallback_email: nil)
    address = mailto_address(fallback_email: fallback_email)
    return nil if address.blank?

    "mailto:#{address}"
  end

  def contacted_recently?(on: Date.current)
    last_contacted_on.present? && last_contacted_on >= on - RECENT_CONTACT_DAYS.days
  end

  private

  def normalize_fields
    self.channel = channel.to_s.strip.downcase.presence
    self.details = details.to_s.strip.presence
    self.note = note.to_s.strip.presence
  end
end
