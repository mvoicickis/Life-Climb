class User < ApplicationRecord
  include TextLimits

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :completions, dependent: :destroy
  has_many :daily_logs, dependent: :destroy
  has_many :feedbacks, dependent: :destroy

  has_many :dreams, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :steps, dependent: :destroy
  has_many :buildings, dependent: :destroy
  has_many :today_actions, dependent: :destroy
  has_many :finished_products, dependent: :destroy
  has_many :life_point_ledgers, dependent: :destroy

  belongs_to :focus_building, class_name: "Building", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            length: { maximum: EMAIL_MAX },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: PASSWORD_MIN, maximum: PASSWORD_MAX }, if: -> { password.present? }
  validates :home_stat_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 20
  }

  def admin?
    admin
  end

  def life_points
    total_points
  end

  def onboarding_completed?
    onboarding_completed_at.present?
  end

  def needs_onboarding?
    !onboarding_completed? && dreams.none?
  end

  def active_dream
    dreams.active.order(:id).first || dreams.order(:id).first
  end

  def primary_goal
    active_dream&.goals&.active&.ordered&.first || goals.active.ordered.first
  end

  def points_today
    completions.where(completed_on: Date.current).sum(:points_awarded)
  end

  def home_trackers
    habits.active.on_home.ordered.limit(home_stat_count)
  end

  def home_board_habits
    habits.active.on_home.ordered
  end

  def days_invested
    today_actions.complete.select(:scheduled_on).distinct.count
  end

  def support_prompts_muted?
    support_prompts_muted
  end
end
