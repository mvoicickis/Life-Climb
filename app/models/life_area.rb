class LifeArea < ApplicationRecord
  include TextLimits

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

  EMOJI = {
    "self" => "🧠",
    "love" => "❤️",
    "family" => "👨‍👩‍👧",
    "community" => "👥",
    "humanity" => "🌍",
    "animals" => "🐾",
    "nature" => "🌿",
    "physical_world" => "🏠"
  }.freeze

  SIMPLE_LABEL_KEYS = {
    "self" => "self",
    "love" => "love",
    "family" => "family",
    "community" => "community",
    "humanity" => "humanity",
    "animals" => "animals",
    "nature" => "nature",
    "physical_world" => "physical_world"
  }.freeze

  belongs_to :user
  belongs_to :dream
  has_many :goals, dependent: :nullify

  validates :key, presence: true, inclusion: { in: KEYS }
  validates :number, presence: true, inclusion: { in: 1..8 }
  validates :ambition, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :present_scene, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :closer_score, numericality: { only_integer: true, in: 1..5 }
  validates :key, uniqueness: { scope: :dream_id }

  scope :ordered, -> { order(:position, :number, :id) }
  scope :filled, -> { where.not(ambition: [ nil, "" ]) }
  scope :tree, -> { where(key: KEYS).ordered }

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
    EMOJI.fetch(key, "🌳")
  end

  def vitality
    closer_score.to_i.clamp(1, 5)
  end

  def bump_closer!
    return false if closer_score >= 5

    update!(closer_score: closer_score + 1)
    true
  end

  def label
    I18n.t("life_parts.#{SIMPLE_LABEL_KEYS.fetch(key)}.name")
  end

  def short_label
    I18n.t("life_parts.#{SIMPLE_LABEL_KEYS.fetch(key)}.short")
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
end
