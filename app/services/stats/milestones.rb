# frozen_string_literal: true

module Stats
  class Milestones
    DISPLAY_KEYS = %w[
      first_battle
      battles_10
      first_camp
      battles_100
      closer_25
      closer_50
      closer_100
    ].freeze
    LOCKED_SHOWN = 2

    def self.call(user:, battle_wins:, mountain_summary:, strategy_goal:, any_finished_path_camp: false,
                  any_completed_journey: false)
      new(
        user: user,
        battle_wins: battle_wins,
        mountain_summary: mountain_summary,
        strategy_goal: strategy_goal,
        any_finished_path_camp: any_finished_path_camp,
        any_completed_journey: any_completed_journey
      ).display
    end

    def initialize(user:, battle_wins:, mountain_summary:, strategy_goal:, any_finished_path_camp: false,
                   any_completed_journey: false)
      @user = user
      @battle_wins = battle_wins
      @mountain_summary = mountain_summary || {}
      @strategy_goal = strategy_goal
      @any_finished_path_camp = any_finished_path_camp
      @any_completed_journey = any_completed_journey
    end

    def display
      catalog = DISPLAY_KEYS.map { |key| entry(key) }
      earned = catalog.select { |badge| badge[:unlocked] }
      locked = catalog.reject { |badge| badge[:unlocked] }
      earned + sort_locked(locked).first(LOCKED_SHOWN)
    end

    private

    def entry(key)
      unlocked = unlocked?(key)
      {
        key: key,
        unlocked: unlocked,
        title: I18n.t("progress.achievements.#{key}"),
        hint: I18n.t("progress.achievements.#{key}_hint"),
        locked_hint: I18n.t("progress.achievements.#{key}_locked_hint")
      }
    end

    def unlocked?(key)
      battles = @battle_wins.all_time_total
      mountain = mountain_percent
      camps_done = @mountain_summary[:projects_done].to_i

      case key
      when "first_battle" then battles >= 1
      when "battles_10" then battles >= 10
      when "first_camp" then @any_finished_path_camp || camps_done >= 1
      when "battles_100" then battles >= 100
      when "closer_25" then @any_completed_journey || mountain >= 25
      when "closer_50" then @any_completed_journey || mountain >= 50
      when "closer_100" then @any_completed_journey || mountain >= 100
      else false
      end
    end

    def mountain_percent
      return 0 unless @strategy_goal

      Strategy::Progress.percent(@strategy_goal)
    end

    def sort_locked(locked)
      battles = @battle_wins.all_time_total
      mountain = mountain_percent

      locked.sort_by do |badge|
        -achievement_proximity(badge[:key], battles: battles, mountain: mountain)
      end
    end

    def achievement_proximity(key, battles:, mountain:)
      threshold = case key
      when "first_battle" then 1
      when "battles_10" then 10
      when "first_camp" then 1
      when "battles_100" then 100
      when "closer_25" then 25
      when "closer_50" then 50
      when "closer_100" then 100
      else return 0.0
      end

      current = case key
      when "first_battle", "battles_10", "battles_100" then battles
      when "first_camp"
        if @any_finished_path_camp
          1
        else
          @mountain_summary[:projects_done].to_i
        end
      when "closer_25", "closer_50", "closer_100"
        @any_completed_journey ? 100 : mountain
      else mountain
      end

      [ current.to_f / threshold, 1.0 ].min
    end
  end
end
