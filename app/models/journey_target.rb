# frozen_string_literal: true

class JourneyTarget < ApplicationRecord
  include TextLimits

  KINDS = %w[oneshot count].freeze
  STATUSES = %w[active completed].freeze

  belongs_to :life_journey
  belongs_to :user

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :target_value, numericality: { greater_than: 0 }
  validates :current_value, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, length: { maximum: 40 }, allow_blank: true

  before_validation :normalize_tags
  before_validation :sync_user_from_journey, on: :create

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:position, :id) }

  def oneshot?
    kind == "oneshot"
  end

  def count?
    kind == "count"
  end

  def completed?
    status == "completed"
  end

  def progress_percent
    return 100 if completed?
    return oneshot? ? (current_value.to_f.positive? ? 100 : 0) : 0 if target_value.to_f <= 0

    ((current_value.to_f / target_value.to_f) * 100).clamp(0, 100).round
  end

  def progress_label
    if completed?
      I18n.t("dash.target_done")
    elsif oneshot?
      current_value.to_f.positive? ? I18n.t("dash.target_done") : "0/1"
    else
      unit_bit = unit.present? ? " #{unit}" : ""
      "#{current_value.to_f.round(current_value.to_f == current_value.to_i ? 0 : 1)}/#{target_value.to_f.round(target_value.to_f == target_value.to_i ? 0 : 1)}#{unit_bit}"
    end
  end

  def log!(amount: nil)
    raise ArgumentError, "Already complete" if completed?

    if oneshot?
      self.current_value = target_value
      self.status = "completed"
    else
      delta = amount.nil? ? 1 : amount.to_f
      raise ArgumentError, "Amount required" if delta <= 0

      self.current_value = current_value.to_f + delta
      self.status = "completed" if current_value.to_f >= target_value.to_f
    end
    save!

    Gap::ApplyProgress.call(journey: life_journey, tier: :target) if completed? || count?
    self
  end

  private

  def normalize_tags
    self.tags = Array(tags).flat_map { |t| t.to_s.split(/[,\s]+/) }.map { |t| t.strip.downcase }.compact_blank.uniq
  end

  def sync_user_from_journey
    self.user_id ||= life_journey&.user_id
  end
end
