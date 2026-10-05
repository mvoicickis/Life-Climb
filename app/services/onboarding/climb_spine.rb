# frozen_string_literal: true

module Onboarding
  # Goal + ordered camps → journey spine (plan, projects, seed battle, setup flags).
  # Used by Bootstrap; does not mark onboarding complete.
  class ClimbSpine
    class Error < StandardError; end

    Result = Bootstrap::Result

    def self.call(user:, goal_title:, camp_titles:)
      new(user:, goal_title:, camp_titles:).call
    end

    def initialize(user:, goal_title:, camp_titles:)
      @user = user
      @goal_title = goal_title.to_s.strip
      @camp_titles = Array(camp_titles)
    end

    def call
      raise Error, I18n.t("v2_onboarding.need_goal") if @goal_title.blank?
      raise Error, I18n.t("v2_onboarding.need_camp") if @camp_titles.empty?

      journey = nil
      goal = nil
      plan = nil
      projects = []
      first_battle = nil

      areas = LifeAreas::Select.call(user: @user, keys: [ Bootstrap::DEFAULT_AREA_KEY ])
      primary_area = areas.find { |a| a.key == Bootstrap::DEFAULT_AREA_KEY } || areas.first

      journey = Journeys::Create.call(
        user: @user,
        life_area: primary_area,
        title: @goal_title,
        ideal_scene: I18n.t("v2_onboarding.default_ideal", title: @goal_title),
        current_reality: I18n.t("v2_onboarding.default_reality"),
        next_win: nil,
        closer_percent: 5
      )

      easy = Today::Commitment::PRESETS.fetch(Bootstrap::DEFAULT_COMMITMENT)
      journey.update!(
        commitment_key: Bootstrap::DEFAULT_COMMITMENT,
        commitment_name: easy[:name],
        commitment_habit_count: 0,
        commitment_battle_count: 1,
        commitment_level_up_declined_on: nil
      )
      Focus::SetJourneys.call(user: @user, journey_ids: [ journey.id ])

      due_on = Strategy::YearCycle.default_goal_due
      goal = @user.strategy_goals.create!(
        life_area: primary_area,
        life_journey: journey,
        horizon: "goal",
        title: @goal_title,
        position: 0,
        due_on: due_on
      )
      Strategy::Celebrate.call(user: @user, goal: goal)

      plan = create_child!(
        parent: goal,
        horizon: "plan",
        title: I18n.t("v2_onboarding.climb_plan_title"),
        life_area: primary_area,
        life_journey: journey,
        position: 0
      )

      total = @camp_titles.size
      @camp_titles.each_with_index do |title, index|
        trail_slot_index = total - 1 - index
        slot = MountainTrailHelper::AutoSlot.call(index: trail_slot_index, total: total)
        projects << create_child!(
          parent: plan,
          horizon: "project",
          title: title,
          life_area: primary_area,
          life_journey: journey,
          position: index,
          stage: index,
          trail_x: slot[:trail_x],
          trail_y: slot[:trail_y]
        )
      end

      first_project = projects.first
      first_battle = create_child!(
        parent: first_project,
        horizon: "day",
        title: default_seed_battle_title,
        life_area: primary_area,
        life_journey: journey,
        scheduled_on: Date.current,
        position: 0
      )

      Strategy::CascadeToDaily.call(user: @user, life_area: primary_area)

      flags = (journey.setup_flags.presence || {}).stringify_keys.merge(
        Onboarding::Categories::CATEGORY_FLAG => Bootstrap::DEFAULT_CATEGORY,
        Bootstrap::BOOTSTRAP_FLAG => "true",
        Bootstrap::FIRST_CAMP_REVEAL_FLAG => "pending",
        Bootstrap::FIRST_CAMP_ID_FLAG => first_project.id
      )
      journey.update_columns(setup_flags: flags, updated_at: Time.current)
      journey.setup_flags = flags

      Result.new(journey: journey, goal: goal, plan: plan, projects: projects, first_battle: first_battle)
    rescue LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error,
           ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def default_seed_battle_title
      Array(I18n.t("strategy.rpg.trail.battle_suggestions")).first.to_s.strip.presence ||
        "Take the first small step"
    end

    def create_child!(parent:, horizon:, title:, life_area:, life_journey:, scheduled_on: nil, position: nil,
                      stage: :__unset__, trail_x: nil, trail_y: nil)
      scope = @user.strategy_goals.where(life_area_id: life_area.id).for_kind(horizon).where(parent_id: parent.id)
      pos = position.nil? ? scope.maximum(:position).to_i + 1 : position
      record = @user.strategy_goals.new(
        life_area: life_area,
        life_journey: life_journey,
        parent: parent,
        horizon: horizon,
        title: title,
        scheduled_on: scheduled_on,
        position: pos,
        trail_x: trail_x,
        trail_y: trail_y
      )
      unless stage == :__unset__
        record.stage = stage
        record.stage_explicit = true
      end
      record.save!
      record
    end
  end
end
