# frozen_string_literal: true

module Today
  # Daily survival against the Journey commitment tier (N timed battles + N green habits).
  class Commitment
    PRESETS = {
      "easy" => { name: "Easy", habit_count: 1, battle_count: 1 },
      "medium" => { name: "Medium", habit_count: 3, battle_count: 3 },
      "hard" => { name: "Hard", habit_count: 5, battle_count: 5 }
    }.freeze

    LEVEL_UP_DAYS = 3

    class IneligibleError < StandardError
      attr_reader :eligibility

      def initialize(eligibility)
        @eligibility = eligibility
        super("Commitment tier ineligible")
      end
    end

    Progress = Struct.new(
      :habit_required, :habit_done, :battle_required, :battle_done,
      :habit_green_ids, :battle_ids, :met, :journey,
      keyword_init: true
    ) do
      def met?
        met
      end
    end

    Eligibility = Struct.new(
      :eligible, :key, :habit_have, :habit_need, :camp_have, :camp_need,
      :missing_habits, :missing_camps,
      keyword_init: true
    ) do
      def eligible?
        eligible
      end
    end

    # What is missing right now so today can be won on the current tier counts.
    # No bootstrap exemption — separate from tier eligibility / apply_preset!.
    SetupGap = Struct.new(
      :kind, # :habits | :battles | :set_time
      :habit_have, :habit_need,
      :battle_have, :battle_need,
      :timed_have,
      :todo,
      keyword_init: true
    )

    def self.progress(user:, journey:, date: Date.current)
      new(user:, journey:, date:).progress
    end

    # One next setup step so #progress can become met on this tier. Priority:
    # habits → battle count → set time (set_time skipped at/after overdue hour).
    def self.setup_gap(user:, journey:, date: Date.current)
      return nil if user.blank? || journey.blank?

      habit_need = journey.commitment_habit_count.to_i
      battle_need = journey.commitment_battle_count.to_i
      habit_have = user.habits.active.on_home.count
      todos = user.daily_todos.for_day(date).ordered.to_a
      battle_have = todos.size
      timed_have = todos.count(&:timed?)

      if habit_have < habit_need
        return SetupGap.new(
          kind: :habits,
          habit_have: habit_have,
          habit_need: habit_need,
          battle_have: battle_have,
          battle_need: battle_need,
          timed_have: timed_have
        )
      end

      if battle_have < battle_need
        return SetupGap.new(
          kind: :battles,
          habit_have: habit_have,
          habit_need: habit_need,
          battle_have: battle_have,
          battle_need: battle_need,
          timed_have: timed_have
        )
      end

      if timed_have < battle_need &&
          Time.current.hour < Strategy::NextAction::OVERDUE_AFTER_HOUR
        untimed = todos.find { |todo| !todo.timed? && !todo.completed? } ||
                  todos.find { |todo| !todo.timed? }
        if untimed
          return SetupGap.new(
            kind: :set_time,
            habit_have: habit_have,
            habit_need: habit_need,
            battle_have: battle_have,
            battle_need: battle_need,
            timed_have: timed_have,
            todo: untimed
          )
        end
      end

      nil
    end

    def self.touch_met_streak!(user:, journey:, date: Date.current)
      new(user:, journey:, date:).touch_met_streak!
    end

    def self.suggest_level_up?(journey:, date: Date.current)
      new(user: journey.user, journey:, date:).suggest_level_up?
    end

    def self.eligibility(user:, key:, journey: nil)
      key = key.to_s
      return ineligible_unknown(key) unless PRESETS.key?(key)

      eligibility_for_counts(
        user: user,
        journey: journey,
        habit_count: PRESETS[key][:habit_count],
        battle_count: PRESETS[key][:battle_count],
        key: key
      )
    end

    def self.eligible_for?(user:, key:, journey: nil)
      eligibility(user:, key:, journey:).eligible?
    end

    # Shared Settings flash / NextAction banner copy for an Eligibility gap.
    def self.gap_alert(elig, name: nil)
      name = name.presence || PRESETS.dig(elig.key, :name) || elig.key.to_s.capitalize
      parts = []
      if elig.missing_habits
        parts << I18n.t(
          "settings.commitment.eligibility.habits",
          name: name,
          need: elig.habit_need,
          have: elig.habit_have
        )
      end
      if elig.missing_camps
        parts << I18n.t(
          "settings.commitment.eligibility.camps",
          name: name,
          need: elig.camp_need,
          have: elig.camp_have
        )
      end
      parts.join(" ")
    end

    def self.eligibility_for_counts(user:, journey:, habit_count:, battle_count:, key: "custom")
      habit_need = habit_count.to_i
      camp_need = battle_count.to_i
      habit_have = user.habits.active.on_home.count
      camp_have = camp_capacity(journey)

      easy = PRESETS.fetch("easy")
      bootstrap = habit_need <= easy[:habit_count] && camp_need <= easy[:battle_count]

      missing_habits = !bootstrap && habit_have < habit_need
      missing_camps = !bootstrap && camp_have < camp_need
      eligible = bootstrap || (!missing_habits && !missing_camps)

      Eligibility.new(
        eligible: eligible,
        key: key.to_s,
        habit_have: habit_have,
        habit_need: habit_need,
        camp_have: camp_have,
        camp_need: camp_need,
        missing_habits: missing_habits,
        missing_camps: missing_camps
      )
    end

    # Incomplete day-capable camps under the journey spine.
    # Nested leaf camps count; path-level camps with no nested project child count as 1.
    def self.camp_capacity(journey)
      return 0 if journey.blank?

      user = journey.user
      goal = user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      return 0 if goal.blank?

      capacity = 0
      each_project_under(goal) do |node|
        next if node.completed?

        if node.nested_leaf_camp?
          capacity += 1
        elsif node.path_level_camp? && node.children.none?(&:project?)
          capacity += 1
        end
      end
      capacity
    end

    def self.apply_preset!(journey, key)
      key = key.to_s
      preset = PRESETS[key]
      raise ArgumentError, "unknown commitment key #{key.inspect}" unless preset

      unless key == "easy" || key == journey.commitment_key.to_s
        elig = eligibility(user: journey.user, key: key, journey: journey)
        raise IneligibleError, elig unless elig.eligible?
      end

      journey.update!(
        commitment_key: key,
        commitment_name: preset[:name],
        commitment_habit_count: preset[:habit_count],
        commitment_battle_count: preset[:battle_count],
        commitment_level_up_declined_on: nil
      )
    end

    def self.level_up_preset!(journey)
      next_key = case journey.commitment_key.to_s
      when "easy" then "medium"
      when "medium" then "hard"
      else nil
      end
      return false if next_key.blank?
      return false unless eligible_for?(user: journey.user, key: next_key, journey: journey)

      apply_preset!(journey, next_key)
      true
    rescue IneligibleError
      false
    end

    def self.decline_level_up!(journey, date: Date.current)
      journey.update!(commitment_level_up_declined_on: date)
    end

    def self.apply_custom!(journey, name:, habit_count:, battle_count:)
      habit_count = habit_count.to_i.clamp(0, 20)
      battle_count = battle_count.to_i.clamp(0, 20)
      elig = eligibility_for_counts(
        user: journey.user,
        journey: journey,
        habit_count: habit_count,
        battle_count: battle_count,
        key: "custom"
      )
      raise IneligibleError, elig unless elig.eligible?

      journey.update!(
        commitment_key: "custom",
        commitment_name: name.to_s.strip.presence || "Custom",
        commitment_habit_count: habit_count,
        commitment_battle_count: battle_count,
        commitment_level_up_declined_on: nil
      )
    end

    def self.next_level_key(journey)
      case journey.commitment_key.to_s
      when "easy" then "medium"
      when "medium" then "hard"
      end
    end

    def initialize(user:, journey:, date: Date.current)
      @user = user
      @journey = journey
      @date = date
    end

    def progress
      return empty_progress if @journey.blank?

      habits = @user.habits.active.on_home.to_a
      green = habits.select { |habit| habit.survived_today?(@date) }

      todos = @user.daily_todos.for_day(@date).to_a
      timed_done = todos.select { |todo| todo.timed? && todo.completed? }

      habit_required = @journey.commitment_habit_count.to_i
      battle_required = @journey.commitment_battle_count.to_i
      habit_done = [ green.size, habit_required ].min
      battle_done = [ timed_done.size, battle_required ].min
      met = habit_done >= habit_required && battle_done >= battle_required

      Progress.new(
        habit_required: habit_required,
        habit_done: habit_done,
        battle_required: battle_required,
        battle_done: battle_done,
        habit_green_ids: green.map(&:id),
        battle_ids: timed_done.map(&:id),
        met: met,
        journey: @journey
      )
    end

    def touch_met_streak!
      return if @journey.blank?

      result = progress
      if result.met?
        return result if @journey.commitment_met_on == @date

        days =
          if @journey.commitment_met_on == @date - 1
            @journey.commitment_met_streak_days.to_i + 1
          else
            1
          end
        @journey.update!(commitment_met_streak_days: days, commitment_met_on: @date)
      elsif @journey.commitment_met_on.present? && @journey.commitment_met_on < @date - 1
        @journey.update!(commitment_met_streak_days: 0) if @journey.commitment_met_streak_days.to_i.positive?
      elsif !result.met? && @journey.commitment_met_on == @date - 1
        # Yesterday counted; today not yet met — keep streak until day rolls without a meet.
      end

      result
    end

    def suggest_level_up?
      return false if @journey.blank?
      return false unless %w[easy medium].include?(@journey.commitment_key.to_s)
      return false if @journey.commitment_level_up_declined_on == @date
      return false if @journey.commitment_met_streak_days.to_i < LEVEL_UP_DAYS

      next_key = self.class.next_level_key(@journey)
      return false if next_key.blank?
      return false unless self.class.eligible_for?(user: @user, key: next_key, journey: @journey)

      true
    end

    # Walk Goal → Plan → Project spine (and nested project camps).
    def self.each_project_under(node, &block)
      node.children.ordered.each do |child|
        if child.holding?
          next
        elsif child.project?
          yield child
          each_project_under(child, &block)
        elsif child.plan?
          each_project_under(child, &block)
        end
      end
    end
    private_class_method :each_project_under

    def self.ineligible_unknown(key)
      Eligibility.new(
        eligible: false,
        key: key,
        habit_have: 0,
        habit_need: 0,
        camp_have: 0,
        camp_need: 0,
        missing_habits: true,
        missing_camps: true
      )
    end
    private_class_method :ineligible_unknown

    private

    def empty_progress
      Progress.new(
        habit_required: 0, habit_done: 0, battle_required: 0, battle_done: 0,
        habit_green_ids: [], battle_ids: [], met: false, journey: nil
      )
    end
  end
end
