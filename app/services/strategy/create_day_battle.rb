# frozen_string_literal: true

module Strategy
  # Shared path for planting an open day under a camp (Mountain #510 suggestion create).
  # Save → Celebrate → CascadeToDaily.sync_goal! — same as StrategyGoalsController day create
  # without seed_win. scheduled_on defaults to Date.current (Time.zone today).
  class CreateDayBattle
    class Invalid < StandardError; end

    def self.call(user:, project:, title:, scheduled_on: Date.current)
      new(user: user, project: project, title: title, scheduled_on: scheduled_on).call
    end

    def initialize(user:, project:, title:, scheduled_on:)
      @user = user
      @project = project
      @title = title.to_s.strip
      @scheduled_on = scheduled_on
    end

    def call
      validate!

      battle = nil
      StrategyGoal.transaction do
        position = next_position
        battle = @user.strategy_goals.create!(
          life_area: @project.life_area,
          life_journey_id: @project.life_journey_id,
          parent: @project,
          horizon: "day",
          title: @title,
          scheduled_on: @scheduled_on,
          repeat: "none",
          position: position
        )
        Strategy::Celebrate.call(user: @user, goal: battle)
        Strategy::CascadeToDaily.sync_goal!(user: @user, goal: battle)
      end
      battle
    end

    private

    def validate!
      raise Invalid, "project_missing" if @project.blank? || !@project.project?
      raise Invalid, "not_authorized" unless @project.user_id == @user.id
      raise Invalid, "blank_title" if @title.blank?
    end

    def next_position
      scope = @user.strategy_goals
        .where(life_area_id: @project.life_area_id, parent_id: @project.id)
        .for_kind("day")
      (scope.maximum(:position) || -1) + 1
    end
  end
end
