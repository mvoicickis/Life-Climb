# frozen_string_literal: true

class BetaSignup < ApplicationRecord
  scope :newest_first, -> { order(created_at: :desc) }

  DEVICES = [
    Admin::DeviceFromUserAgent::DEVICE_ANDROID,
    Admin::DeviceFromUserAgent::DEVICE_IPHONE,
    Admin::DeviceFromUserAgent::DEVICE_COMPUTER
  ].map(&:to_s).freeze

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :device, inclusion: { in: DEVICES }, allow_nil: true

  before_validation :assign_device_from_user_agent

  private

  def assign_device_from_user_agent
    return if device.present?
    return if user_agent.blank?

    classified = Admin::DeviceFromUserAgent.call(user_agent)
    self.device = classified&.to_s
  end
end
