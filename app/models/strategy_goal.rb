# frozen_string_literal: true

class StrategyGoal < ApplicationRecord
  include TextLimits

  # Guided tree: Goal → Plans → path Projects → Battles.
  # Path-level projects hold days only. Nested projects are not allowed.
  # Legacy month/week rows are migrated away; year maps to goal.
  KINDS = %w[goal plan project day].freeze
  LEGACY_KINDS = %w[month week].freeze
  LEGACY_KIND = { "year" => "goal" }.freeze
  REPEAT_KINDS = %w[none daily].freeze
  COLOR_KEYS = %w[teal coral amber purple blue green pink gray].freeze
  QUANTITY_KINDS = %w[none up down range].freeze
  EFFORT_TIERS = %w[light steady heavy].freeze

  ALLOWED_CHILDREN = {
    "goal" => %w[plan],
    "plan" => %w[project],
    "project" => %w[day],
    "day" => []
  }.freeze

  belongs_to :user
  belongs_to :life_area
  belongs_to :life_journey, optional: true
  belongs_to :parent, class_name: "StrategyGoal", optional: true
  has_many :children, class_name: "StrategyGoal", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :habit_project_links, dependent: :destroy, inverse_of: :strategy_goal
  has_many :linked_habits, through: :habit_project_links, source: :habit
  has_many :practice_tasks, dependent: :destroy
  # Open Today rows are purged below; completed history is nullified (AP already awarded).
  has_many :daily_todos, dependent: :nullify
  has_many :strategy_quantity_logs, dependent: :destroy
  # Quantity logs may point at a day as the battle source without owning the project.
  has_many :sourced_quantity_logs,
           class_name: "StrategyQuantityLog",
           foreign_key: :source_day_id,
           dependent: :nullify,
           inverse_of: :source_day

  before_destroy :destroy_open_daily_todos, prepend: true
  before_destroy :reparent_descendant_battles_to_holding!, prepend: true
  before_destroy :prevent_user_destroy_of_holding, prepend: true

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :description, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :horizon, presence: true, inclusion: { in: KINDS + LEGACY_KINDS + LEGACY_KIND.keys }
  validates :repeat, presence: true, inclusion: { in: REPEAT_KINDS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :current_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, length: { maximum: 40 }, allow_blank: true
  validates :color_key, inclusion: { in: COLOR_KEYS }, allow_nil: true
  validates :effort_tier, inclusion: { in: EFFORT_TIERS }, allow_nil: true
  validates :trail_x, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :trail_y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validate :scheduled_on_required_for_day
  validate :repeat_allowed_for_kind
  validate :due_on_rules
  validate :parent_kind_matches
  validate :parent_leaf_branch_xor
  validate :child_fits_parent_window
  validate :root_must_be_goal
  validate :legacy_kinds_readonly, on: :create
  validate :quantity_target_rules
  validate :holding_shape
  validate :holding_plan_accepts_only_holding_camp
  validate :one_destination_per_journey, on: :create
  validate :one_plan_per_goal, on: :create
  validate :trail_coords_shape

  before_validation :normalize_legacy_kind
  before_validation :normalize_repeat
  before_validation :normalize_quantity_fields
  before_validation :normalize_color_key
  before_validation :normalize_effort_tier
  before_validation :normalize_trail_coords
  before_validation :assign_goal_due_on, if: -> { kind == "goal" }

  scope :ordered, -> { order(:position, :id) }
  scope :for_horizon, ->(horizon) { where(horizon: horizon) }
  scope :for_kind, ->(kind) {
    keys = [ kind ]
    keys << "year" if kind.to_s == "goal"
    where(horizon: keys)
  }
  scope :for_area, ->(area_id) { where(life_area_id: area_id) }
  scope :roots, -> { where(parent_id: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :for_day, ->(date = Date.current) { where(horizon: "day", scheduled_on: date) }
  scope :battles, -> { where(horizon: "day") }
  scope :not_holding, -> { where(holding: false) }

  def self.with_holding_destroy
    prior = Thread.current[:strategy_goal_allow_holding_destroy]
    Thread.current[:strategy_goal_allow_holding_destroy] = true
    yield
  ensure
    Thread.current[:strategy_goal_allow_holding_destroy] = prior
  end

  def completed?
    completed_at.present?
  end

  def manually_completed?
    manually_completed_at.present?
  end

  def kind
    LEGACY_KIND.fetch(horizon.to_s, horizon.to_s)
  end

  def goal?
    kind == "goal"
  end

  def plan?
    kind == "plan"
  end

  def project?
    kind == "project"
  end

  def month?
    kind == "month"
  end

  def week?
    kind == "week"
  end

  def day?
    kind == "day"
  end

  def repeat_daily?
    day? && repeat.to_s == "daily"
  end

  def allowed_child_kinds
    ALLOWED_CHILDREN.fetch(kind, [])
  end

  # Leftover nested folders from before flatten. New trees never branch.
  def branch_checkpoint?
    project? && children.any?(&:project?)
  end

  def leaf_checkpoint?
    project? && children.none?(&:project?)
  end

  # Camp hanging directly under a Path (plan).
  def path_level_camp?
    project? && parent&.plan?
  end

  # Path Project linked to one or more Trackers (via habit_project_links).
  def tracker_linked?
    if association(:habit_project_links).loaded?
      habit_project_links.any?
    else
      habit_project_links.exists?
    end
  end

  # Leftover nested folder that held days before flatten. Always false after migration.
  def nested_leaf_camp?
    project? && parent&.project? && leaf_checkpoint?
  end

  # Curated accent key for Quest cards / Today rows (nil = default styling).
  def tagged_color_key
    key = color_key.to_s.presence
    COLOR_KEYS.include?(key) ? key : nil
  end

  # Path-level project with a numeric target (pages, €, emails, …).
  def quantified?
    return false unless path_level_camp?

    kind = quantity_kind_value
    return true if %w[up down].include?(kind) && target_amount.present? && target_amount.to_d.positive?
    return true if kind == "range" && range_min.present? && range_max.present?

    # Legacy rows before quantity_kind existed.
    kind == "none" && target_amount.present? && target_amount.to_d.positive?
  end

  def quantity_kind_value
    raw = has_attribute?(:quantity_kind) ? quantity_kind.to_s : "none"
    QUANTITY_KINDS.include?(raw) ? raw : "none"
  end

  def quantity_up?
    quantity_kind_value == "up" || (quantity_kind_value == "none" && quantified?)
  end

  def quantity_down?
    quantity_kind_value == "down"
  end

  def quantity_range?
    quantity_kind_value == "range"
  end

  # Walk up from a day/battle (or nested camp) to the quantified path-level project.
  def quantified_path_project
    return self if quantified?

    node = self
    while node
      return node if node.quantified?
      node = node.parent
    end
    nil
  end

  # Nested quest folders are gone. Path camps take days, never nested projects.
  def split_eligible?
    false
  end

  # True when this Practice has objectives and every one is checked off.
  def all_objectives_complete?
    day? && practice_tasks.any? && practice_tasks.all?(&:completed?)
  end

  def aspect_key
    key = life_area&.key.to_s
    return key if LifeArea::HOME_ASPECT_KEYS.include?(key)

    "self"
  end

  def overdue?
    return false if completed?

    marker = day? ? scheduled_on : due_on
    marker.present? && marker < Date.current
  end

  def time_marker
    day? ? scheduled_on : due_on
  end

  def progress_percent
    Strategy::Progress.percent(self)
  end

  def ancestor_chain
    chain = []
    node = parent
    while node
      chain.unshift(node)
      node = node.parent
    end
    chain
  end

  def root_goal
    return self if goal?

    ancestor_chain.find(&:goal?) || ancestors_fallback
  end

  def descendant_battles
    Strategy::Progress.battles_under(self)
  end

  def complete!
    update!(completed_at: Time.current) if completed_at.blank?
  end

  def reopen!
    update!(completed_at: nil) if completed_at.present?
  end

  # Sticky override — survives SyncCompletion.resync! when real % < 100.
  def manually_complete!
    touch_time = Time.current
    update!(
      completed_at: completed_at.presence || touch_time,
      manually_completed_at: touch_time
    )
  end

  def manually_reopen!
    update!(completed_at: nil, manually_completed_at: nil)
  end

  private

  # Phantom Today battles: open DailyTodos must not outlive their Mountain day/quest.
  # Completed rows keep AP history via dependent: :nullify (strategy_goal_id cleared).
  def destroy_open_daily_todos
    daily_todos.incomplete.find_each(&:destroy!)
  end

  def ancestors_fallback
    node = self
    node = node.parent while node.parent
    node
  end

  def normalize_legacy_kind
    self.horizon = LEGACY_KIND[horizon] if LEGACY_KIND.key?(horizon.to_s)
  end

  def normalize_repeat
    value = repeat.to_s.presence || "none"
    value = "none" unless day?
    value = "none" unless REPEAT_KINDS.include?(value)
    self.repeat = value
  end

  def normalize_quantity_fields
    # Fires on every StrategyGoal create/update — must be safe when quantity
    # columns are nil (normal goals/plans/days) and always use explicit readers.
    return unless has_attribute?(:unit)

    self.unit = self.unit.to_s.strip.presence
    self.current_amount = 0 if self.current_amount.nil?
    self.unit = nil if self.target_amount.blank?
  end

  def normalize_color_key
    return unless has_attribute?(:color_key)

    self.color_key = holding? ? nil : color_key.to_s.strip.presence
  end

  def normalize_effort_tier
    return unless has_attribute?(:effort_tier)

    self.effort_tier = effort_tier.to_s.strip.presence
  end

  # Trail placement is only for visible path projects. Holding / other kinds clear coords.
  def normalize_trail_coords
    return unless has_attribute?(:trail_x)

    unless project? && !holding?
      self.trail_x = nil
      self.trail_y = nil
      return
    end

    self.trail_x = trail_x.presence
    self.trail_y = trail_y.presence
  end

  def trail_coords_shape
    return unless has_attribute?(:trail_x)
    return if trail_x.blank? && trail_y.blank?
    return if project? && !holding? && trail_x.present? && trail_y.present?

    if holding? || !project?
      errors.add(:trail_x, :invalid) if trail_x.present?
      errors.add(:trail_y, :invalid) if trail_y.present?
    elsif trail_x.blank? ^ trail_y.blank?
      errors.add(:trail_x, :blank) if trail_x.blank?
      errors.add(:trail_y, :blank) if trail_y.blank?
    end
  end

  def quantity_target_rules
    return unless has_attribute?(:target_amount)

    if holding?
      errors.add(:target_amount, :invalid) if self.target_amount.present?
      errors.add(:unit, :invalid) if self.unit.present?
      errors.add(:quantity_kind, :invalid) if has_attribute?(:quantity_kind) && quantity_kind_value != "none"
      return
    end

    kind = quantity_kind_value
    if kind == "none"
      if self.target_amount.blank?
        errors.add(:unit, :invalid) if self.unit.present?
        return
      end
      # Legacy up via target_amount alone.
      kind = "up"
    end

    unless project?
      errors.add(:target_amount, :invalid) if self.target_amount.present?
      errors.add(:quantity_kind, :invalid) if kind != "none"
      return
    end

    unless path_level_camp?
      errors.add(:target_amount, :invalid) if self.target_amount.present?
      errors.add(:quantity_kind, :invalid) if kind != "none"
      return
    end

    errors.add(:unit, :blank) if self.unit.blank?

    case kind
    when "up", "down"
      errors.add(:target_amount, :blank) if self.target_amount.blank?
      if self.target_amount.present?
        errors.add(:target_amount, :greater_than, count: 0) unless self.target_amount.to_d.positive?
      end
    when "range"
      errors.add(:range_min, :blank) if range_min.blank?
      errors.add(:range_max, :blank) if range_max.blank?
      if range_min.present? && range_max.present? && range_min.to_d > range_max.to_d
        errors.add(:range_max, :invalid)
      end
    end
  end

  def assign_goal_due_on
    return if due_on.present?

    self.due_on = Strategy::YearCycle.default_goal_due
  end

  def scheduled_on_required_for_day
    return unless day?
    return if scheduled_on.present?

    errors.add(:scheduled_on, :blank)
  end

  def repeat_allowed_for_kind
    return if repeat.to_s == "none"
    return if day? && REPEAT_KINDS.include?(repeat.to_s)

    errors.add(:repeat, :invalid)
  end

  def due_on_rules
    return unless kind == "goal"

    errors.add(:due_on, :blank) if due_on.blank?
    return if due_on.blank?
    # Only enforce the floor for new goals or when the date itself changes,
    # so existing past/legacy Dec 29 due dates are left alone.
    return unless new_record? || will_save_change_to_due_on?

    errors.add(:due_on, :invalid) if due_on < Date.current
  end

  def parent_kind_matches
    return if parent.blank?
    return if parent.allowed_child_kinds.include?(kind)

    errors.add(:parent_id, :invalid)
  end

  # Leaf XOR branch: a checkpoint has day children or project children, never both.
  def parent_leaf_branch_xor
    return if parent.blank?
    return unless parent.project?

    siblings =
      if parent.association(:children).loaded?
        parent.children.reject { |c| c.id == id }
      else
        parent.children.where.not(id: id).to_a
      end

    if project? && siblings.any?(&:day?)
      errors.add(:base, I18n.t("strategy.rpg.checkpoint_split_blocked"))
    elsif day? && siblings.any?(&:project?)
      errors.add(:base, I18n.t("strategy.rpg.checkpoint_branch_no_days"))
    end
  end

  def holding_shape
    return unless holding?

    if plan?
      errors.add(:parent_id, :invalid) unless parent&.goal?
      return
    end

    if project? && parent&.plan? && parent.holding?
      return
    end

    errors.add(:holding, :invalid)
  end

  def holding_plan_accepts_only_holding_camp
    return unless parent&.holding? && parent.plan?
    return if holding? && project?

    errors.add(:parent_id, :invalid)
  end

  # One destination (root goal) per journey unless the user is entitled to
  # more (Premium seam on User#extra_destinations_allowed?). App-level rule,
  # not a DB constraint, so it can be gated per user without a migration.
  def one_destination_per_journey
    return unless goal? && parent_id.nil?
    return if user&.extra_destinations_allowed?

    siblings = StrategyGoal.for_kind("goal").roots
      .where(user_id: user_id, life_journey_id: life_journey_id)
      .where.not(id: id)
    return unless siblings.exists?

    errors.add(:base, I18n.t("strategy.rpg.one_destination_only"))
  end

  # One non-holding Plan per goal unless the user is entitled to more. The
  # #323 holding Plan is skipped, so it never collides with the rule.
  def one_plan_per_goal
    return unless plan?
    return if holding?
    return if parent_id.blank?
    return if user&.extra_plans_allowed?

    siblings = StrategyGoal.for_kind("plan").not_holding
      .where(parent_id: parent_id)
      .where.not(id: id)
    return unless siblings.exists?

    errors.add(:base, I18n.t("strategy.rpg.one_plan_only"))
  end

  def prevent_user_destroy_of_holding
    return unless holding?
    return if destroyed_by_association
    return if Thread.current[:strategy_goal_allow_holding_destroy]

    throw :abort
  end

  # Snapshot → move → reset cached children → verify. Do not reorder.
  def reparent_descendant_battles_to_holding!
    return unless project?
    return if holding?
    return if Thread.current[:strategy_goal_allow_holding_destroy]

    snapshot_ids = Strategy::Progress.battles_under(self).map(&:id)
    return if snapshot_ids.empty?

    camp = holding_camp_for_reparent!
    StrategyGoal.where(id: snapshot_ids).find_each do |battle|
      battle.update!(parent: camp)
    end

    children.reset
    descendant_project_ids_for_reset.each do |folder_id|
      folder = StrategyGoal.find_by(id: folder_id)
      folder&.association(:children)&.reset
    end

    leftover = Strategy::Progress.battles_under(reload).map(&:id) & snapshot_ids
    return if leftover.empty?

    raise "holding reparent left battles #{leftover.join(',')}"
  end

  def holding_camp_for_reparent!
    journey = life_journey ||
              user.life_journeys.find_by(id: life_journey_id) ||
              user.life_journeys.find_by(life_area_id: life_area_id) ||
              user.primary_focused_journey
    Strategy::HoldingProject.ensure!(user: user, journey: journey)
  end

  def descendant_project_ids_for_reset
    ids = []
    frontier = [ id ]
    while frontier.any?
      kids = StrategyGoal.where(parent_id: frontier, horizon: "project").pluck(:id)
      break if kids.empty?

      ids.concat(kids)
      frontier = kids
    end
    ids
  end

  def root_must_be_goal
    return if parent.present?
    return if goal?

    errors.add(:horizon, :invalid)
  end

  def child_fits_parent_window
    return if parent.blank?

    child_date = day? ? scheduled_on : due_on
    parent_due = parent.due_on
    return if child_date.blank? || parent_due.blank?
    return if child_date <= parent_due

    errors.add(:due_on, :invalid)
  end

  def legacy_kinds_readonly
    return unless LEGACY_KINDS.include?(horizon.to_s)

    errors.add(:horizon, :invalid)
  end
end
