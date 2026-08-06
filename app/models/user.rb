class User < ApplicationRecord
  include TextLimits
  include UserOtp

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
  has_many :strategy_point_ledgers, dependent: :destroy
  has_many :strategy_goals, dependent: :destroy
  has_many :strategy_quantity_logs, dependent: :destroy
  has_many :practice_tasks, dependent: :destroy
  has_many :life_journeys, dependent: :destroy
  has_many :missions, dependent: :destroy
  has_many :journey_targets, dependent: :destroy
  has_many :daily_todos, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_one :notification_preference, dependent: :destroy

  belongs_to :focus_building, class_name: "Building", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.to_s.strip.squeeze(" ").presence }

  validates :email_address, presence: true, uniqueness: true,
            length: { maximum: EMAIL_MAX },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: NAME_MAX }, on: :create
  validates :name, length: { maximum: NAME_MAX }, allow_blank: true
  validates :password, length: { minimum: PASSWORD_MIN, maximum: PASSWORD_MAX }, if: -> { password.present? }
  validates :home_stat_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 20
  }
  validates :character, inclusion: { in: ->(_) { CHARACTERS } }, allow_nil: true,
            if: :validate_character_value?
  validates :planning_version, inclusion: { in: [ 1, 2 ] }
  validates :locale, inclusion: {
    in: ->(_) { I18n.available_locales.map(&:to_s) }
  }, allow_nil: true
  validates :theme, inclusion: { in: ->(_) { THEMES } }

  # Current companion set. Legacy man/woman remain in DB until the user re-picks.
  CHARACTERS = %w[birdie bee bear fox horse raven].freeze
  LEGACY_CHARACTERS = %w[man woman].freeze
  THEMES = %w[light dark].freeze
  ADVENTURE_GUIDE_KEY = "adventure_guide".freeze
  COMPANION_PICK_KEY = "companion_pick".freeze

  def admin?
    admin
  end

  # True when the DB flag is set or the email is in DEVELOPER_EMAIL / DEVELOPER_EMAILS.
  def developer?
    DeveloperAccess.allowed?(self)
  end

  def planning_v2?
    planning_version.to_i >= 2
  end

  def selected_life_areas
    planning_v2? ? life_areas.v2_selected : (active_dream&.life_areas&.tree || life_areas.none)
  end

  def focused_journeys
    life_journeys.focused
  end

  def primary_focused_journey
    life_journeys.primary_focus.first
  end

  def needs_onboarding?
    return !onboarding_completed? if planning_v2?

    !onboarding_completed? && dreams.none?
  end

  def life_points
    total_points
  end

  def action_points
    total_points
  end

  def character_key
    character.presence_in(CHARACTERS)
  end

  def theme_key
    theme.presence_in(THEMES) || "light"
  end

  def character_chosen?
    character_key.present?
  end

  def character_image
    key = character_key
    return nil if key.blank?

    "characters/#{key}.png"
  end

  def legacy_character?
    LEGACY_CHARACTERS.include?(character.to_s)
  end

  def companion_pick_done?
    Array(support_milestones_shown).map(&:to_s).include?(COMPANION_PICK_KEY)
  end

  # Soft prompt for onboarded users still on blank / man / woman.
  def needs_companion_pick?
    planning_v2? && onboarding_completed? && !character_chosen?
  end

  def mark_companion_pick_done!
    shown = Array(support_milestones_shown).map(&:to_s)
    return if shown.include?(COMPANION_PICK_KEY)

    update!(support_milestones_shown: shown + [ COMPANION_PICK_KEY ])
  end

  # Lazy-create prefs on first Notifications visit (not on User create).
  def notification_preference!
    notification_preference || create_notification_preference!
  end

  def display_name
    name.to_s.strip.presence || email_address.to_s.split("@").first.to_s.titleize.presence || "there"
  end

  def ledger_points_today
    life_point_ledgers.where(created_at: Time.current.all_day).sum(:amount)
  end

  def overall_gap_percent(areas = nil)
    if planning_v2?
      journeys = focused_journeys.presence || life_journeys.active
      return 0 if journeys.empty?

      return (journeys.sum { |j| j.gap_percent.to_f } / journeys.size).round
    end

    (100 - overall_closer_percent(areas)).clamp(0, 100)
  end

  def overall_closer_percent(areas = nil)
    if planning_v2?
      return (100 - overall_gap_percent).clamp(0, 100)
    end

    areas = Array(areas.presence || active_dream&.life_areas&.tree)
    return 0 if areas.empty?

    (areas.sum { |a| a.closer_percent } / areas.size.to_f).round
  end

  def onboarding_completed?
    onboarding_completed_at.present?
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

  def adventure_guide_done?
    Array(support_milestones_shown).map(&:to_s).include?(ADVENTURE_GUIDE_KEY)
  end

  def needs_adventure_guide?
    planning_v2? && onboarding_completed? && !adventure_guide_done?
  end

  def mark_adventure_guide_done!
    shown = Array(support_milestones_shown).map(&:to_s)
    return if shown.include?(ADVENTURE_GUIDE_KEY)

    update!(support_milestones_shown: shown + [ ADVENTURE_GUIDE_KEY ])
  end

  def alive_level
    AliveLevel.new(life_points)
  end

  def focus_life_area
    focus_building&.goal&.life_area ||
      primary_goal&.life_area ||
      active_dream&.life_areas&.filled&.ordered&.first
  end

  private

  # Keep legacy man/woman rows valid until re-pick; validate new writes only.
  def validate_character_value?
    return true if character.blank?
    return true if will_save_change_to_character?
    return true if CHARACTERS.include?(character.to_s)

    false
  end
end
