class User < ApplicationRecord
  include TextLimits

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :completions, dependent: :destroy
  has_many :daily_logs, dependent: :destroy
  has_many :feedbacks, dependent: :destroy

  has_many :dreams, dependent: :destroy
  has_many :life_areas, dependent: :destroy
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
  validates :character, inclusion: { in: %w[man woman] }, allow_nil: true

  CHARACTERS = %w[man woman].freeze

  def admin?
    admin
  end

  def life_points
    total_points
  end

  def character_key
    character.presence_in(CHARACTERS) || "man"
  end

  def character_chosen?
    character.present?
  end

  def character_image
    "characters/character-#{character_key}.png"
  end

  def display_name
    email_address.to_s.split("@").first.to_s.titleize.presence || "there"
  end

  def ledger_points_today
    life_point_ledgers.where(created_at: Time.current.all_day).sum(:amount)
  end

  def overall_gap_percent(areas = nil)
    areas = Array(areas.presence || active_dream&.life_areas&.ordered)
    return 100 if areas.empty?

    closer_avg = areas.sum { |a| a.closer_percent } / areas.size.to_f
    (100 - closer_avg).round
  end

  def morale_score(actions: [])
    actions = Array(actions)
    if actions.any?
      ((actions.count(&:completed?).to_f / actions.size) * 100).round
    else
      areas = active_dream&.life_areas
      return 40 if areas.blank?

      (areas.map(&:closer_percent).sum / areas.size.to_f).round
    end
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

  def alive_level
    AliveLevel.new(life_points)
  end

  def focus_life_area
    focus_building&.goal&.life_area ||
      primary_goal&.life_area ||
      active_dream&.life_areas&.filled&.ordered&.first
  end
end
