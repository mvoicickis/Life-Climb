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

    Progress = Struct.new(
      :habit_required, :habit_done, :battle_required, :battle_done,
      :habit_green_ids, :battle_ids, :met, :journey,
      keyword_init: true
    ) do
      def met?
        met
      end
    end

    def self.progress(user:, journey:, date: Date.current)
      new(user:, journey:, date:).progress
    end

    def self.touch_met_streak!(user:, journey:, date: Date.current)
      new(user:, journey:, date:).touch_met_streak!
    end

    def self.suggest_level_up?(journey:, date: Date.current)
      new(user: journey.user, journey:, date:).suggest_level_up?
    end

    def self.apply_preset!(journey, key)
      preset = PRESETS[key.to_s]
      raise ArgumentError, "unknown commitment key #{key.inspect}" unless preset

      journey.update!(
        commitment_key: key.to_s,
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

      apply_preset!(journey, next_key)
      true
    end

    def self.decline_level_up!(journey, date: Date.current)
      journey.update!(commitment_level_up_declined_on: date)
    end

    def self.apply_custom!(journey, name:, habit_count:, battle_count:)
      journey.update!(
        commitment_key: "custom",
        commitment_name: name.to_s.strip.presence || "Custom",
        commitment_habit_count: habit_count.to_i.clamp(0, 20),
        commitment_battle_count: battle_count.to_i.clamp(0, 20),
        commitment_level_up_declined_on: nil
      )
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

      true
    end

    private

    def empty_progress
      Progress.new(
        habit_required: 0, habit_done: 0, battle_required: 0, battle_done: 0,
        habit_green_ids: [], battle_ids: [], met: false, journey: nil
      )
    end
  end
end
