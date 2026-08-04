# frozen_string_literal: true

class LifeJourney < ApplicationRecord
  include TextLimits

  STATUSES = %w[draft active completed archived].freeze

  STRATEGY_BRIEF_KEYS = %w[why rules how path done_vs_now to_show].freeze

  # Unlock-the-climb layers (Progress meter is always available, not gated).
  CLIMB_LAYERS = %w[goal purpose policy approach program milestone scenes finished today].freeze
  SKIPPABLE_LAYERS = %w[purpose policy approach program finished].freeze
  LIST_LAYERS = {
    "approach" => :approaches,
    "program" => :programs,
    "milestone" => :milestones
  }.freeze
  LEGACY_LIST_FIELDS = {
    approaches: :approach,
    programs: :program,
    milestones: :next_win
  }.freeze

  LAYER_FIELDS = {
    "goal" => %i[title],
    "purpose" => %i[purpose],
    "policy" => %i[policy],
    "approach" => %i[approaches],
    "program" => %i[programs],
    "milestone" => %i[milestones],
    "scenes" => %i[ideal_scene current_reality],
    "finished" => %i[finished_result],
    "today" => %i[today_mission]
  }.freeze

  belongs_to :user
  belongs_to :life_area
  has_many :missions, dependent: :destroy
  has_many :gap_snapshots, dependent: :destroy
  has_many :journey_targets, dependent: :destroy
  has_many :habits, dependent: :nullify

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
  after_initialize :ensure_json_defaults

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
    ensure_json_defaults
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

    flags = (setup_flags.presence || {}).stringify_keys.merge(layer => status.to_s)
    # update_columns avoids JSON dirty-tracking misses on SQLite defaults.
    update_columns(setup_flags: flags, updated_at: Time.current)
    self.setup_flags = flags
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

  def approaches_list
    climb_list_for(:approaches)
  end

  def programs_list
    climb_list_for(:programs)
  end

  def milestones_list
    climb_list_for(:milestones)
  end

  def approaches_items
    climb_items_for(:approaches)
  end

  def programs_items
    climb_items_for(:programs)
  end

  def milestones_items
    climb_items_for(:milestones)
  end

  def primary_milestone
    milestones_list.first
  end

  def climb_card_title
    primary_milestone.presence || title
  end

  def list_present?(kind)
    climb_list_for(kind).any?
  end

  def strategy_brief_hash
    (strategy_brief.presence || {}).stringify_keys
  end

  def strategy_brief_value(key)
    strategy_brief_hash[key.to_s].to_s
  end

  def update_strategy_brief!(attrs)
    merged = strategy_brief_hash
    STRATEGY_BRIEF_KEYS.each do |key|
      next unless attrs.key?(key) || attrs.key?(key.to_sym)

      merged[key] = attrs[key].presence || attrs[key.to_sym].presence || ""
    end
    update!(strategy_brief: merged)
  end

  def replace_list!(kind, entries)
    kind = kind.to_sym
    raise ArgumentError, "Unknown list" unless LEGACY_LIST_FIELDS.key?(kind)

    items = normalize_climb_entries(entries)
    legacy = LEGACY_LIST_FIELDS.fetch(kind)
    update!(
      kind => items,
      legacy => items.first&.fetch("title")
    )
  end

  def layer_summary(layer, today_mission: nil, today_todos: nil)
    case layer.to_s
    when "goal" then title
    when "purpose" then purpose
    when "policy" then policy
    when "approach" then approaches_list.first(3).join(" · ")
    when "program" then programs_list.first(3).join(" · ")
    when "milestone" then milestones_list.first(3).join(" · ")
    when "scenes" then [ ideal_scene, current_reality ].compact_blank.join(" · ")
    when "finished" then finished_result
    when "today"
      titles = Array(today_todos).map(&:title).compact_blank
      titles = [ today_mission&.title ].compact_blank if titles.empty?
      titles.first(3).join(" · ")
    end
  end

  def bootstrap_setup_flags_from_content!(today_mission: nil, today_todos: nil)
    flags = (setup_flags.presence || {}).stringify_keys
    changed = false
    todos = Array(today_todos)

    CLIMB_LAYERS.each do |layer|
      next if %w[done skipped].include?(flags[layer])

      has_content =
        case layer
        when "goal" then title.present?
        when "purpose" then purpose.present?
        when "policy" then policy.present?
        when "approach" then list_present?(:approaches)
        when "program" then list_present?(:programs)
        when "milestone" then list_present?(:milestones)
        when "scenes" then ideal_scene.present? && current_reality.present?
        when "finished" then finished_result.present?
        when "today" then today_mission&.title.present? || todos.any? { |t| t.title.present? }
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

    return unless changed

    update_columns(setup_flags: flags, updated_at: Time.current)
    self.setup_flags = flags
  end

  private

  def climb_list_for(kind)
    climb_items_for(kind).map { |item| item["title"] }
  end

  def climb_items_for(kind)
    kind = kind.to_sym
    raw = Array(public_send(kind))
    items = raw.filter_map { |entry| normalize_climb_entry(entry) }
    return items if items.any?

    legacy = LEGACY_LIST_FIELDS[kind]
    return [] unless legacy

    value = public_send(legacy).to_s.strip
    value.present? ? [ { "title" => value, "tags" => [] } ] : []
  end

  def normalize_climb_entries(entries)
    Array(entries).filter_map { |entry| normalize_climb_entry(entry) }
  end

  def normalize_climb_entry(entry)
    if entry.respond_to?(:permit)
      entry = entry.permit(:title, :tags, :tag, tags: []).to_h
    end

    case entry
    when Hash
      h = entry.with_indifferent_access
      title = h[:title].to_s.strip
      return nil if title.blank?

      tags = Array(h[:tags]).flat_map { |t| t.to_s.split(/[,\s]+/) }.map { |t| t.strip.downcase }.compact_blank.uniq
      tags = h[:tag].to_s.split(/[,\s]+/).map { |t| t.strip.downcase }.compact_blank.uniq if tags.empty? && h[:tag].present?
      { "title" => title.truncate(SUMMARY_MAX), "tags" => tags }
    else
      title = entry.to_s.strip
      return nil if title.blank?

      { "title" => title.truncate(SUMMARY_MAX), "tags" => [] }
    end
  end

  def ensure_json_defaults
    self.setup_flags = {} if read_attribute(:setup_flags).nil?
    self.approaches = [] if has_attribute?(:approaches) && read_attribute(:approaches).nil?
    self.programs = [] if has_attribute?(:programs) && read_attribute(:programs).nil?
    self.milestones = [] if has_attribute?(:milestones) && read_attribute(:milestones).nil?
    self.strategy_brief = {} if has_attribute?(:strategy_brief) && read_attribute(:strategy_brief).nil?
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
