# frozen_string_literal: true

class AppSetting < ApplicationRecord
  KEYS = {
    maintenance_mode: "maintenance_mode",
    announcement_banner: "announcement_banner",
    feature_feedback_inbox: "feature.feedback_inbox",
    feature_export_stats: "feature.export_stats"
  }.freeze

  validates :key, presence: true, uniqueness: true
  validates :value, length: { maximum: 2000 }, allow_nil: true

  def self.read(key, default: nil)
    return default unless table_available?

    find_by(key: key.to_s)&.value.presence || default
  end

  def self.write(key, value)
    record = find_or_initialize_by(key: key.to_s)
    record.value = value.nil? ? nil : value.to_s
    record.save!
    record
  end

  def self.truthy?(key)
    ActiveModel::Type::Boolean.new.cast(read(key))
  end

  def self.maintenance_mode?
    truthy?(KEYS[:maintenance_mode])
  end

  def self.announcement_banner
    read(KEYS[:announcement_banner]).to_s.strip.presence
  end

  def self.table_available?
    connection.data_source_exists?(table_name)
  rescue StandardError
    false
  end
end
