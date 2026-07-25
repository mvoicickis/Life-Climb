class LifeArea < ApplicationRecord
  include TextLimits

  # Legacy fixed octagon (planning_version 1 / dream-backed rows).
  KEYS = %w[
    self
    love
    family
    community
    humanity
    animals
    nature
    physical_world
  ].freeze

  # v2 catalog — user selects any subset (soft UX default 1–3).
  CATALOG = [
    { key: "self", emoji: "😊" },
    { key: "relationships", emoji: "❤️" },
    { key: "family", emoji: "👨‍👩‍👧" },
    { key: "career", emoji: "💼" },
    { key: "money", emoji: "💰" },
    { key: "home", emoji: "🏠" },
    { key: "community", emoji: "👥" },
    { key: "humanity", emoji: "🌍" },
    { key: "nature", emoji: "🌿" },
    { key: "animals", emoji: "🐾" },
    { key: "learning", emoji: "📚" },
    { key: "creativity", emoji: "🎨" },
    { key: "purpose", emoji: "✨" }
  ].freeze

  CATALOG_KEYS = CATALOG.map { |entry| entry[:key] }.freeze

  EMOJI = {
    "self" => "🧠",
    "love" => "❤️",
    "family" => "👨‍👩‍👧",
    "community" => "👥",
    "humanity" => "🌍",
    "animals" => "🐾",
    "nature" => "🌿",
    "physical_world" => "🏠",
    "relationships" => "❤️",
    "career" => "💼",
    "money" => "💰",
    "home" => "🏠",
    "learning" => "📚",
    "creativity" => "🎨",
    "purpose" => "✨"
  }.freeze

  SIMPLE_LABEL_KEYS = {
    "self" => "self",
    "love" => "love",
    "family" => "family",
    "community" => "community",
    "humanity" => "humanity",
    "animals" => "animals",
    "nature" => "nature",
    "physical_world" => "physical_world",
    "relationships" => "relationships",
    "career" => "career",
    "money" => "money",
    "home" => "home",
    "learning" => "learning",
    "creativity" => "creativity",
    "purpose" => "purpose"
  }.freeze

  belongs_to :user
  belongs_to :dream, optional: true
  has_many :goals, dependent: :nullify
  has_many :life_journeys, dependent: :restrict_with_error

  validates :key, presence: true
  validate :key_must_be_known
  validates :number, presence: true, inclusion: { in: 1..20 }
  validates :ambition, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :present_scene, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :closer_score, numericality: { only_integer: true, in: 1..5 }
  validates :key, uniqueness: { scope: :dream_id }, if: -> { dream_id.present? }
  validates :key, uniqueness: {
    scope: :user_id,
    conditions: -> { where(dream_id: nil) }
  }, if: -> { dream_id.nil? }

  scope :ordered, -> { order(:position, :number, :id) }
  scope :filled, -> { where.not(ambition: [ nil, "" ]) }
  scope :tree, -> { where(key: KEYS).ordered }
  scope :v2_selected, -> { where(dream_id: nil).where.not(selected_at: nil).ordered }

  def filled?
    ambition.to_s.strip.present?
  end

  def present_filled?
    present_scene.to_s.strip.present?
  end

  def compare_ready?
    filled? && present_filled?
  end

  def ideal
    ambition.to_s.strip
  end

  def present
    present_scene.to_s.strip
  end

  def closer_percent
    return journey_closer_percent if v2_selected?

    ((closer_score.to_i.clamp(1, 5) - 1) / 4.0 * 100).round
  end

  def goal_reached?
    closer_percent >= 100
  end

  def closer_label
    I18n.t("closer_labels.#{closer_score.to_i.clamp(1, 5)}")
  end

  def emoji
    catalog = CATALOG.find { |entry| entry[:key] == key }
    catalog&.fetch(:emoji) || EMOJI.fetch(key, "🌳")
  end

  # Tree branch health: 1 (far/neglected) … 5 (gap nearly closed / blooming).
  def vitality
    return journey_vitality if v2_selected?

    closer_score.to_i.clamp(1, 5)
  end

  def representative_journey
    return nil unless v2_selected?

    life_journeys.focused.order(:focus_position).first ||
      life_journeys.active.order(updated_at: :desc).first ||
      life_journeys.order(updated_at: :desc).first
  end

  def journey_gap_percent
    representative_journey&.gap_percent&.to_f
  end

  def journey_closer_percent
    gap = journey_gap_percent
    return 0 if gap.nil?

    (100.0 - gap).clamp(0, 100).round
  end

  def journey_vitality
    gap = journey_gap_percent
    return 1 if gap.nil?

    case gap
    when 0...20 then 5
    when 20...40 then 4
    when 40...60 then 3
    when 60...80 then 2
    else 1
    end
  end

  def v2_selected?
    dream_id.nil? && selected_at.present?
  end

  def bump_closer!
    return false if closer_score >= 5

    update!(closer_score: closer_score + 1)
    true
  end

  def label
    if CATALOG_KEYS.include?(key)
      I18n.t("life_area_catalog.#{key}.name")
    else
      I18n.t("life_parts.#{SIMPLE_LABEL_KEYS.fetch(key)}.name")
    end
  end

  def short_label
    if CATALOG_KEYS.include?(key)
      I18n.t("life_area_catalog.#{key}.short")
    else
      I18n.t("life_parts.#{SIMPLE_LABEL_KEYS.fetch(key)}.short")
    end
  end

  def catalog_hint
    return "" unless CATALOG_KEYS.include?(key)

    I18n.t("life_area_catalog.#{key}.hint")
  end

  def active_goal
    goals.active.ordered.first
  end

  def active_building
    Building.joins(step: :goal)
            .where(user_id: user_id, status: "active", goals: { life_area_id: id })
            .order("buildings.id")
            .first
  end

  def focus?
    goal = active_goal
    return false unless goal

    building = user.focus_building
    building.present? && building.goal&.id == goal.id
  end

  def self.catalog_number(key)
    index = CATALOG_KEYS.index(key.to_s)
    index ? index + 1 : 1
  end

  def self.ensure_for_dream!(dream)
    KEYS.each_with_index do |key, index|
      dream.life_areas.find_or_create_by!(key: key) do |area|
        area.user = dream.user
        area.number = index + 1
        area.position = index
        area.closer_score = 1
      end
    end
    dream.life_areas.tree
  end

  private

  def key_must_be_known
    return if key.blank?
    return if KEYS.include?(key)
    return if CATALOG_KEYS.include?(key)

    errors.add(:key, "is not a known life area")
  end
end
