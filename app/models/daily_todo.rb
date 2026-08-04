# frozen_string_literal: true

class DailyTodo < ApplicationRecord
  include TextLimits

  belongs_to :user
  belongs_to :strategy_goal, optional: true
  has_one :strategy_quantity_log, dependent: :nullify

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :aspect_key, presence: true, inclusion: { in: LifeArea::HOME_ASPECT_KEYS }
  validates :scheduled_on, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :lp_reward, numericality: { only_integer: true, greater_than: 0 }
  validate :within_daily_cap, on: :create

  before_validation :assign_default_lp, on: :create

  scope :for_day, ->(date = Date.current) { where(scheduled_on: date) }
  scope :for_aspect, ->(key) { where(aspect_key: key) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  def completed?
    completed_at.present?
  end

  private

  def assign_default_lp
    self.lp_reward = GameRules::BATTLE_TODO_LP if lp_reward.blank? || lp_reward.to_i <= 0
  end

  def within_daily_cap
    return if user.blank? || scheduled_on.blank?

    count = user.daily_todos.for_day(scheduled_on).count
    return if count < GameRules::MAX_DAILY_TODOS

    errors.add(:base, I18n.t("dash.battle_day_full", max: GameRules::MAX_DAILY_TODOS))
  end
end
