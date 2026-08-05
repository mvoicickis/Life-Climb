# frozen_string_literal: true

class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh, presence: true
  validates :auth, presence: true

  def touch_seen!(user_agent: nil)
    attrs = { last_seen_at: Time.current }
    attrs[:user_agent] = user_agent if user_agent.present?
    update!(attrs)
  end
end
