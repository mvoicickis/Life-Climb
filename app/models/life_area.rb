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

  # Short tag list on Home — bigger aspects of life, not the full catalog.
  HOME_ASPECT_KEYS = %w[self relationships career money home learning].freeze
  HOME_ASPECTS = CATALOG.select { |entry| HOME_ASPECT_KEYS.include?(entry[:key]) }.freeze

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
  has_many :life_journeys
  has_many :strategy_goals, dependent: :destroy

  before_destroy :guard_or_cascade_life_journeys

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

  def vitality
    closer_score.to_i.clamp(1, 5)
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

  # Block direct deletes while journeys exist; cascade when destroyed via User.
  def guard_or_cascade_life_journeys
    if destroyed_by_association
      life_journeys.find_each(&:destroy!)
      return
    end

    return unless life_journeys.exists?

    record = self.class.human_attribute_name(:life_journeys).downcase
    errors.add(:base, :'restrict_dependent_destroy.has_many', record: record)
    throw :abort
  end

  def key_must_be_known
    return if key.blank?
    return if KEYS.include?(key)
    return if CATALOG_KEYS.include?(key)

    errors.add(:key, "is not a known life area")
  end
end
