class User < ApplicationRecord
  include TextLimits
  include UserOtp

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :areas, dependent: :destroy
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
  has_many :day_overshoot_bonuses, class_name: "DayOvershootBonus", dependent: :destroy
  has_many :strategy_point_ledgers, dependent: :destroy
  has_many :strategy_goals, dependent: :destroy
  has_many :strategy_quantity_logs, dependent: :destroy
  has_many :practice_tasks, dependent: :destroy
  has_many :life_journeys, dependent: :destroy
  has_many :missions, dependent: :destroy
  has_many :journey_targets, dependent: :destroy
  has_many :daily_todos, dependent: :destroy
  has_many :pattern_snapshots, dependent: :destroy
  has_many :user_events, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :oauth_identities, dependent: :destroy
  has_many :climb_partnerships_as_inviter, class_name: "ClimbPartnership",
           foreign_key: :inviter_id, inverse_of: :inviter, dependent: :destroy
  has_many :climb_partnerships_as_invitee, class_name: "ClimbPartnership",
           foreign_key: :invitee_id, inverse_of: :invitee, dependent: :destroy
  has_many :high_fives_given, class_name: "HighFive",
           foreign_key: :from_user_id, inverse_of: :from_user, dependent: :destroy
  has_many :high_fives_received, class_name: "HighFive",
           foreign_key: :to_user_id, inverse_of: :to_user, dependent: :destroy
  has_one :notification_preference, dependent: :destroy
  has_one :tester_contact, dependent: :destroy

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
  validates :avatar_key, inclusion: { in: ->(_) { AVATAR_KEYS } }, allow_nil: true
  validates :planning_version, inclusion: { in: [ 1, 2 ] }
  validates :locale, inclusion: {
    in: ->(_) { I18n.available_locales.map(&:to_s) }
  }, allow_nil: true
  validates :theme, inclusion: { in: ->(_) { THEMES } }

  before_validation :normalize_avatar_key

  # Current companion set. Legacy man/woman remain in DB until the user re-picks.
  CHARACTERS = %w[birdie bee bear fox horse raven].freeze
  # Onboarding / settings pickers — horse kept in CHARACTERS for existing users.
  PICKABLE_CHARACTERS = (CHARACTERS - %w[horse]).freeze
  LEGACY_CHARACTERS = %w[man woman].freeze
  # Social Climb together avatar (You page / partner row) — not the mountain companion.
  AVATAR_KEYS = %w[bird bear fox wolf].freeze
  THEMES = %w[light dark].freeze
  PREMIUM_ACCESS_STATUSES = %w[active trialing].freeze
  ADVENTURE_GUIDE_KEY = "adventure_guide".freeze
  COMPANION_PICK_KEY = "companion_pick".freeze
  BASE_CAMP_INTRO_KEY = "base_camp_intro".freeze
  DAY_SHIELD_TIP_KEY = "day_shield_tip".freeze
  FIRST_TIP_KEYS = %w[circle mountain camp camp_sheet you_tab habit animal].freeze
  # Legacy daily cap — no longer enforced by FirstTips; methods remain for stale data.
  FIRST_TIP_DAILY_LIMIT = 2
  INSTALL_OFFER_MAX_ASKS = 2
  PUSH_OFFER_MAX_ASKS = 3
  INSTALL_OFFER_RESHOW_AFTER = 30.days

  def admin?
    admin
  end

  # True when the DB flag is set or the email is in DEVELOPER_EMAIL / DEVELOPER_EMAILS.
  def developer?
    DeveloperAccess.allowed?(self)
  end

  def privileged?
    admin? || developer?
  end

  scope :privileged, -> {
    emails = DeveloperAccess.emails
    relation = where(admin: true).or(where(developer: true))
    emails.any? ? relation.or(where(email_address: emails)) : relation
  }

  scope :excluding_privileged, -> { where.not(id: privileged.select(:id)) }

  def planning_v2?
    planning_version.to_i >= 2
  end

  # Premium seam: StrategyGoal validations key off extra_destinations_allowed? /
  # extra_plans_allowed?, which delegate to subscription-backed #premium?.
  def premium?
    return false if current_period_end.blank?
    return false unless current_period_end.future?

    subscription_status.in?(PREMIUM_ACCESS_STATUSES)
  end

  def extra_destinations_allowed?
    premium?
  end

  def extra_plans_allowed?
    premium?
  end

  def subscription_cancel_on_delete?
    return false if stripe_subscription_id.blank?

    !Billing::CancelSubscription::TERMINAL_STATUSES.include?(subscription_status.to_s)
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

  def avatar_image
    key = avatar_key.presence_in(AVATAR_KEYS)
    return nil if key.blank?

    "avatars/#{key}.webp"
  end

  # PNG for Web Push notification icons (Android rejects WebP for showNotification).
  def avatar_push_image
    key = avatar_key.presence_in(AVATAR_KEYS)
    return nil if key.blank?

    "avatars/#{key}.png"
  end

  def legacy_character?
    LEGACY_CHARACTERS.include?(character.to_s)
  end

  def companion_pick_done?
    Array(support_milestones_shown).map(&:to_s).include?(COMPANION_PICK_KEY)
  end

  def base_camp_intro_seen?
    Array(support_milestones_shown).map(&:to_s).include?(BASE_CAMP_INTRO_KEY)
  end

  def needs_base_camp_intro?
    journey = primary_focused_journey
    planning_v2? && onboarding_completed? && !base_camp_intro_seen? && journey&.onboarding_v3?
  end

  def mark_base_camp_intro_seen!
    keys = Array(support_milestones_shown).map(&:to_s)
    return if keys.include?(BASE_CAMP_INTRO_KEY)

    update!(support_milestones_shown: keys + [ BASE_CAMP_INTRO_KEY ])
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

  def local_today
    Battles::WinsOnLocalDate.local_today_for(self)
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

  def day_shield_tip_done?
    Array(support_milestones_shown).map(&:to_s).include?(DAY_SHIELD_TIP_KEY)
  end

  def mark_day_shield_tip_done!
    shown = Array(support_milestones_shown).map(&:to_s)
    return if shown.include?(DAY_SHIELD_TIP_KEY)

    update!(support_milestones_shown: shown + [ DAY_SHIELD_TIP_KEY ])
  end

  def first_tip_milestone_key(key)
    "first_tip_#{key}"
  end

  def first_tip_seen?(key)
    Array(support_milestones_shown).map(&:to_s).include?(first_tip_milestone_key(key))
  end

  def mark_first_tip_seen!(key)
    key = key.to_s
    return unless FIRST_TIP_KEYS.include?(key)

    milestone = first_tip_milestone_key(key)
    shown = Array(support_milestones_shown).map(&:to_s)
    return if shown.include?(milestone)

    update!(support_milestones_shown: shown + [ milestone ])
  end

  def onboarding_local_day_index
    return nil unless onboarding_completed_at

    zone_name = Battles::WinsOnLocalDate.time_zone_for(self)
    zone = Time.find_zone(zone_name)
    completed_on =
      if zone
        onboarding_completed_at.in_time_zone(zone).to_date
      else
        onboarding_completed_at.to_date
      end
    (local_today - completed_on).to_i
  end

  def first_tip_daily_budget_available?
    reset_first_tips_daily_if_stale!
    Array(first_tips_daily_hash["keys"]).size < FIRST_TIP_DAILY_LIMIT
  end

  def record_first_tip_shown_today!(key)
    key = key.to_s
    return if key == "circle"
    return unless FIRST_TIP_KEYS.include?(key)

    reset_first_tips_daily_if_stale!
    data = first_tips_daily_hash
    keys = Array(data["keys"]).map(&:to_s)
    return if keys.include?(key)
    return unless keys.size < FIRST_TIP_DAILY_LIMIT

    keys << key
    update!(first_tips_daily: { "on" => local_today.iso8601, "keys" => keys })
  end

  def reset_first_tips_daily!
    update!(first_tips_daily: {})
  end

  # Any completed DailyTodo counts as a Battle win (Today authority).
  def battle_won_once?
    daily_todos.where.not(completed_at: nil).exists?
  end

  def install_offer_eligible?
    return false unless battle_won_once?
    return false if install_offer_installed_at.present?
    return true if install_offer_dismiss_count.zero?
    return false if install_offer_dismiss_count >= INSTALL_OFFER_MAX_ASKS

    install_offer_dismissed_at.present? &&
      install_offer_dismissed_at <= INSTALL_OFFER_RESHOW_AFTER.ago
  end

  def mark_install_offer_dismissed!
    return if install_offer_installed_at.present?
    return if install_offer_dismiss_count >= INSTALL_OFFER_MAX_ASKS

    update!(
      install_offer_dismiss_count: install_offer_dismiss_count + 1,
      install_offer_dismissed_at: Time.current
    )
  end

  def mark_install_offer_installed!
    return if install_offer_installed_at.present?

    update!(install_offer_installed_at: Time.current)
  end

  def push_offer_eligible?(win_number: nil, endpoint: nil)
    normalized = endpoint.to_s.strip
    if normalized.present?
      return false if push_subscriptions.exists?(endpoint: normalized)
    end

    return false if push_offer_permission_denied_at.present?
    return false if push_offer_dismiss_count >= PUSH_OFFER_MAX_ASKS
    return false if push_offer_show_days >= PUSH_OFFER_MAX_ASKS
    return false if push_offer_shown_today?

    true
  end

  def mark_push_offer_shown!(date: push_offer_local_date, count_show_day: true)
    new_day = push_offer_last_shown_on.nil? || date > push_offer_last_shown_on
    attrs = { push_offer_last_shown_on: date }
    attrs[:push_offer_show_days] = push_offer_show_days + 1 if new_day && count_show_day
    update!(attrs)
  end

  def mark_push_offer_dismissed!
    return if push_offer_dismiss_count >= PUSH_OFFER_MAX_ASKS

    update!(
      push_offer_dismiss_count: push_offer_dismiss_count + 1,
      push_offer_dismissed_at: Time.current
    )
  end

  def mark_push_offer_permission_denied!
    return if push_offer_permission_denied_at.present?

    update!(push_offer_permission_denied_at: Time.current)
  end

  def push_offer_local_date
    zone = notification_preference&.time_zone
    return Date.current if zone.blank?

    Time.current.in_time_zone(zone).to_date
  rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
    Date.current
  end

  def push_offer_shown_today?
    push_offer_last_shown_on.present? &&
      push_offer_last_shown_on == push_offer_local_date
  end

  def alive_level
    AliveLevel.new(life_points)
  end

  def focus_life_area
    focus_building&.goal&.life_area ||
      primary_goal&.life_area ||
      active_dream&.life_areas&.filled&.ordered&.first
  end

  # dependent: :destroy on strategy_goals runs as before_destroy callbacks, which
  # sit outside around_destroy. Wrap the whole destroy so camp→holding reparent
  # cannot create a strategy_goals.parent_id row under a dying destination goal.
  def destroy
    StrategyGoal.with_holding_destroy { super }
  end

  before_destroy :destroy_strategy_goals_depth_first, prepend: true

  private

  # Wipe the goal tree leaves-first so Postgres never deletes a parent row while
  # children still hold strategy_goals.parent_id (LifeArea also cascades goals).
  def destroy_strategy_goals_depth_first
    return unless strategy_goals.exists?

    loop do
      parent_ids = strategy_goals.where.not(parent_id: nil).select(:parent_id)
      leaves = strategy_goals.where.not(id: parent_ids)
      break unless leaves.exists?

      leaves.find_each(&:destroy!)
    end
  end

  # Keep legacy man/woman rows valid until re-pick; validate new writes only.
  def validate_character_value?
    return true if character.blank?
    return true if will_save_change_to_character?
    return true if CHARACTERS.include?(character.to_s)

    false
  end

  def normalize_avatar_key
    self.avatar_key = avatar_key.presence
  end

  def first_tips_daily_hash
    raw = first_tips_daily
    raw.is_a?(Hash) ? raw.stringify_keys : {}
  end

  def reset_first_tips_daily_if_stale!
    data = first_tips_daily_hash
    return if data.blank?

    stored_on = data["on"].to_s
    return if stored_on.blank?
    return if stored_on == local_today.iso8601

    update!(first_tips_daily: {})
  end
end
