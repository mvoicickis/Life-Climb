# frozen_string_literal: true

class StrategyGoal < ApplicationRecord
  include TextLimits

  # Guided tree: Goal → Plans → Projects → Battles.
  # Projects may nest (branch checkpoints) or take days (leaf). Never both.
  # Legacy month/week rows are migrated away; year maps to goal.
  KINDS = %w[goal plan project day].freeze
  LEGACY_KINDS = %w[month week].freeze
  LEGACY_KIND = { "year" => "goal" }.freeze

  ALLOWED_CHILDREN = {
    "goal" => %w[plan],
    "plan" => %w[project],
    "project" => %w[project day],
    "day" => []
  }.freeze

  belongs_to :user
  belongs_to :life_area
  belongs_to :life_journey, optional: true
  belongs_to :parent, class_name: "StrategyGoal", optional: true
  has_many :children, class_name: "StrategyGoal", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :daily_todos, dependent: :nullify

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :description, length: { maximum: SUMMARY_MAX }, allow_blank: true
  validates :horizon, presence: true, inclusion: { in: KINDS + LEGACY_KINDS + LEGACY_KIND.keys }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :scheduled_on_required_for_day
  validate :due_on_rules
  validate :parent_kind_matches
  validate :parent_leaf_branch_xor
  validate :child_fits_parent_window
  validate :root_must_be_goal
  validate :legacy_kinds_readonly, on: :create

  before_validation :normalize_legacy_kind
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

  def completed?
    completed_at.present?
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

  def allowed_child_kinds
    ALLOWED_CHILDREN.fetch(kind, [])
  end

  # Branch = has nested checkpoints. Leaf = takes dailies (or empty, ready for either).
  def branch_checkpoint?
    project? && children.any?(&:project?)
  end

  def leaf_checkpoint?
    project? && children.none?(&:project?)
  end

  def split_eligible?
    project? && children.none?(&:day?)
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

  private

  def ancestors_fallback
    node = self
    node = node.parent while node.parent
    node
  end

  def normalize_legacy_kind
    self.horizon = LEGACY_KIND[horizon] if LEGACY_KIND.key?(horizon.to_s)
  end

  def assign_goal_due_on
    self.due_on = Strategy::YearCycle.target_dec29
  end

  def scheduled_on_required_for_day
    return unless day?
    return if scheduled_on.present?

    errors.add(:scheduled_on, :blank)
  end

  def due_on_rules
    case kind
    when "goal"
      errors.add(:due_on, :blank) if due_on.blank?
      errors.add(:due_on, :invalid) if due_on.present? && !Strategy::YearCycle.dec29?(due_on)
    end
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
