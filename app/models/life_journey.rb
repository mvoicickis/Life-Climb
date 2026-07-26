# frozen_string_literal: true

class LifeJourney < ApplicationRecord
  include TextLimits

  STATUSES = %w[draft active completed archived].freeze

  # Unlock-the-climb layers (Progress meter is always available, not gated).
  CLIMB_LAYERS = %w[goal purpose policy approach program milestone scenes finished today].freeze
  SKIPPABLE_LAYERS = %w[purpose policy approach program finished].freeze

  LAYER_FIELDS = {
    "goal" => %i[title],
    "purpose" => %i[purpose],
    "policy" => %i[policy],
    "approach" => %i[approach],
    "program" => %i[program],
    "milestone" => %i[next_win],
    "scenes" => %i[ideal_scene current_reality],
    "finished" => %i[finished_result],
    "today" => %i[today_mission]
  }.freeze

  belongs_to :user
  belongs_to :life_area
  has_many :missions, dependent: :destroy
  has_many :gap_snapshots, dependent: :destroy

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :ideal_scene, presence: true, length: { maximum: SUMMARY_MAX }
  validates :current_reality, presence: true, length: { maximum: SUMMARY_MAX }
  validates :next_win, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :purpose, :policy, :approach, :program, :finished_result,
            length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :focus_position, inclusion: { in: 1..3 }, allow_nil: true
  validates :gap_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :user_matches_life_area

  before_validation :sync_user_from_area, on: :create
  before_validation :touch_scenes_revised, if: :scenes_changed?
  after_initialize :ensure_setup_flags

  scope :active, -> { where(status: "active") }
  scope :focused, -> { where.not(focus_position: nil).order(:focus_position) }
  scope :primary_focus, -> { where(focus_position: 1) }

  def focused?
    focus_position.present?
  end

  def closer_percent
    (100 - gap_percent.to_f).clamp(0, 100).round(1)
  end

  def gap_yesterday
    gap_snapshots.find_by(recorded_on: Date.current - 1)&.gap_percent
  end

  def gap_delta_vs_yesterday
    yesterday = gap_yesterday
    return nil unless yesterday

    (gap_percent.to_f - yesterday.to_f).round(2)
  end

  def setup_flag(layer)
    ensure_setup_flags
    setup_flags[layer.to_s]
  end

  def layer_done?(layer)
    setup_flag(layer) == "done"
  end

  def layer_skipped?(layer)
    setup_flag(layer) == "skipped"
  end

  def layer_complete?(layer)
    layer_done?(layer) || layer_skipped?(layer)
  end

  def layer_unlocked?(layer)
    layer = layer.to_s
    return false unless CLIMB_LAYERS.include?(layer)
    return true if layer == "goal"

    prev = CLIMB_LAYERS[CLIMB_LAYERS.index(layer) - 1]
    layer_complete?(prev)
  end

  def layer_state(layer)
    layer = layer.to_s
    return :locked unless layer_unlocked?(layer)
    return :complete if layer_complete?(layer)

    :open
  end

  def mark_layer!(layer, status)
    layer = layer.to_s
    raise ArgumentError, "Unknown layer" unless CLIMB_LAYERS.include?(layer)
    raise ArgumentError, "Bad status" unless %w[done skipped].include?(status.to_s)
    raise ArgumentError, "Cannot skip" if status.to_s == "skipped" && !SKIPPABLE_LAYERS.include?(layer)

    ensure_setup_flags
    flags = setup_flags.merge(layer => status.to_s)
    update!(setup_flags: flags)
  end

  def clarity_count
    CLIMB_LAYERS.count { |layer| layer_complete?(layer) }
  end

  def clarity_total
    CLIMB_LAYERS.size
  end

  def first_open_layer
    CLIMB_LAYERS.find { |layer| layer_state(layer) == :open } ||
      CLIMB_LAYERS.find { |layer| layer_state(layer) == :locked } ||
      CLIMB_LAYERS.first
  end

  def layer_summary(layer, today_mission: nil)
    case layer.to_s
    when "goal" then title
    when "purpose" then purpose
    when "policy" then policy
    when "approach" then approach
    when "program" then program
    when "milestone" then next_win
    when "scenes" then [ ideal_scene, current_reality ].compact_blank.join(" · ")
    when "finished" then finished_result
    when "today" then today_mission&.title
    end
  end

  def bootstrap_setup_flags_from_content!(today_mission: nil)
    ensure_setup_flags
    flags = setup_flags.stringify_keys.dup
    changed = false

    CLIMB_LAYERS.each do |layer|
      next if %w[done skipped].include?(flags[layer])

      has_content =
        case layer
        when "goal" then title.present?
        when "purpose" then purpose.present?
        when "policy" then policy.present?
        when "approach" then approach.present?
        when "program" then program.present?
        when "milestone" then next_win.present?
        when "scenes" then ideal_scene.present? && current_reality.present?
        when "finished" then finished_result.present?
        when "today" then today_mission&.title.present?
        else false
        end
      next unless has_content

      prev_ok =
        if layer == "goal"
          true
        else
          %w[done skipped].include?(flags[CLIMB_LAYERS[CLIMB_LAYERS.index(layer) - 1]])
        end
      next unless prev_ok

      flags[layer] = "done"
      changed = true
    end

    update!(setup_flags: flags) if changed
  end

  private

  def ensure_setup_flags
    self.setup_flags = {} if setup_flags.nil?
    self.setup_flags = setup_flags.stringify_keys if setup_flags.is_a?(Hash)
  end

  def sync_user_from_area
    self.user_id ||= life_area&.user_id
  end

  def user_matches_life_area
    return if life_area.blank? || user_id.blank?
    return if life_area.user_id == user_id

    errors.add(:life_area, "must belong to the same user")
  end

  def scenes_changed?
    ideal_scene_changed? || current_reality_changed?
  end

  def touch_scenes_revised
    self.scenes_revised_at = Time.current
  end
end
