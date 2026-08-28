# frozen_string_literal: true

class DailyTodo < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :strategy_goal, optional: true
  has_one :strategy_quantity_log, dependent: :nullify
  has_many :life_point_ledgers, as: :source, dependent: :nullify

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :aspect_key, presence: true, inclusion: { in: LifeArea::HOME_ASPECT_KEYS }
  validates :scheduled_on, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :lp_reward, numericality: { only_integer: true, greater_than: 0 }
  validate :within_daily_cap, on: :create
  validate :time_window_pair

  before_validation :assign_default_lp, on: :create

  scope :for_day, ->(date = Date.current) { where(scheduled_on: date) }
  scope :for_aspect, ->(key) { where(aspect_key: key) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  def completed?
    completed_at.present?
  end

  def timed?
    start_time.present? && end_time.present?
  end

  def quest?
    strategy_goal&.practice_tasks&.any?
  end

  # Path project shown on Today. Holding (and missing parent) stay invisible.
  def visible_path_project
    project = strategy_goal&.parent
    return nil unless project&.project?
    return nil if project.holding?

    project
  end

  def window_start_at
    combine_date_and_time(start_time)
  end

  def window_end_at
    combine_date_and_time(end_time)
  end

  def miss_settled?
    miss_settled_at.present?
  end

  def miss_shielded?
    miss_settled? && !life_point_ledgers.where("amount < 0").exists?
  end

  def missed?
    miss_settled? && !miss_shielded?
  end

  def time_range_label
    return nil unless timed?

    "#{format_clock(start_time)} – #{format_clock(end_time)}"
  end

  private

  def assign_default_lp
    self.lp_reward = GameRules::BATTLE_TODO_LP if lp_reward.blank? || lp_reward.to_i <= 0
  end

  def within_daily_cap
    return if user.blank? || scheduled_on.blank?

    return unless GameRules.daily_open_cap_reached?(user, scheduled_on)

    errors.add(:base, I18n.t("dash.battle_day_full", max: GameRules::MAX_DAILY_TODOS))
  end

  def time_window_pair
    if start_time.blank? && end_time.blank?
      return
    end

    if start_time.blank? || end_time.blank?
      errors.add(:base, I18n.t("dash.timeline.need_both_times"))
      return
    end

    return if window_end_at > window_start_at

    errors.add(:base, I18n.t("dash.timeline.end_after_start"))
  end

  def combine_date_and_time(clock)
    return nil if clock.blank? || scheduled_on.blank?

    Time.zone.local(
      scheduled_on.year,
      scheduled_on.month,
      scheduled_on.day,
      clock.hour,
      clock.min,
      clock.sec
    )
  end

  def format_clock(clock)
    clock.strftime("%H:%M")
  end
end
