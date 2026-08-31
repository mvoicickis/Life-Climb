# frozen_string_literal: true

class UserEvent < ApplicationRecord
  belongs_to :user

  validates :name, presence: true

  scope :named, ->(name) { where(name: name) }
end
