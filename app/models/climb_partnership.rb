# frozen_string_literal: true

class ClimbPartnership < ApplicationRecord
  STATUSES = %w[pending active ended].freeze

  belongs_to :inviter, class_name: "User"
  belongs_to :invitee, class_name: "User", optional: true

  validates :token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validate :invitee_not_inviter

  before_validation :ensure_token, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :active, -> { where(status: "active") }
  scope :ended, -> { where(status: "ended") }

  scope :involving, ->(user) {
    where(inviter_id: user.id).or(where(invitee_id: user.id))
  }

  def self.active_for(user)
    active.involving(user)
  end

  def self.pending_invite_by(user)
    pending.where(inviter_id: user.id).order(:id).first
  end

  def pending?
    status == "pending"
  end

  def active?
    status == "active"
  end

  def partner_of(user)
    return invitee if user.id == inviter_id
    return inviter if invitee_id.present? && user.id == invitee_id

    nil
  end

  private

  def ensure_token
    self.token = SecureRandom.urlsafe_base64(16) if token.blank?
  end

  def invitee_not_inviter
    return if invitee_id.blank? || inviter_id.blank?
    return if invitee_id != inviter_id

    errors.add(:invitee_id, "can't be the same as the inviter")
  end
end
