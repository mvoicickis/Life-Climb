# frozen_string_literal: true

class OauthIdentity < ApplicationRecord
  GOOGLE = "google"

  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true
end
