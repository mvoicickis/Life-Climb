# frozen_string_literal: true

module Today
  # Win-state copy + next-step key for Today V2 when all battles are won.
  class BattlefieldPrompt
    Result = Struct.new(
      :prompt_key,
      :won_count,
      :headline,
      :sub,
      :project_check,
      :battle_angle_project,
      :battle_angles,
      :upcoming_battle,
      :battles_waiting_count,
      keyword_init: true
    )

    def self.call(
      health:,
      project_check: nil,
      battle_angle_project: nil,
      battle_angles: nil,
      battles_waiting_count: 0,
      upcoming_battle: nil
    )
      new(
        health: health,
        project_check: project_check,
        battle_angle_project: battle_angle_project,
        battle_angles: battle_angles,
        battles_waiting_count: battles_waiting_count,
        upcoming_battle: upcoming_battle
      ).call
    end

    def initialize(
      health:,
      project_check:,
      battle_angle_project:,
      battle_angles:,
      battles_waiting_count:,
      upcoming_battle:
    )
      @health = health
      @project_check = project_check
      @battle_angle_project = battle_angle_project
      @battle_angles = Array(battle_angles)
      @battles_waiting_count = battles_waiting_count.to_i
      @upcoming_battle = upcoming_battle
    end

    def call
      return nil unless @health&.all_clear?

      won_count = @health.done_count
      prompt_key = resolve_key

      Result.new(
        prompt_key: prompt_key,
        won_count: won_count,
        headline: headline_for(prompt_key, won_count),
        sub: sub_for(prompt_key, won_count),
        project_check: @project_check,
        battle_angle_project: @battle_angle_project,
        battle_angles: @battle_angles,
        upcoming_battle: @upcoming_battle,
        battles_waiting_count: @battles_waiting_count
      )
    end

    private

    def resolve_key
      return :battles_waiting if @battles_waiting_count.positive?
      return :upcoming if @upcoming_battle.present?

      :day_won
    end

    def headline_for(prompt_key, won_count)
      scope = "dash.battlefield.win_state.#{prompt_key}.headline"
      vars = headline_vars_for(prompt_key, won_count)

      if I18n.exists?("#{scope}.one")
        I18n.t(scope, **vars)
      else
        I18n.t(scope, **vars, default: I18n.t("dash.battlefield.win_state.day_won.headline", count: won_count))
      end
    end

    def headline_vars_for(prompt_key, won_count)
      case prompt_key
      when :battles_waiting
        { count: @battles_waiting_count }
      when :upcoming
        { title: @upcoming_battle[:title], count: won_count }
      else
        { count: won_count }
      end
    end

    def sub_for(prompt_key, won_count)
      scope = "dash.battlefield.win_state.#{prompt_key}.sub"
      vars = { count: won_count }
      if prompt_key == :upcoming && @upcoming_battle
        vars[:title] = @upcoming_battle[:title]
        vars[:date] = I18n.l(@upcoming_battle[:scheduled_on], format: :short) if @upcoming_battle[:scheduled_on]
      end
      I18n.t(scope, **vars)
    end
  end
end
