# frozen_string_literal: true

module Onboarding
  # New-player onboarding: goal + ordered camps → full spine on Today.
  # All-or-nothing transaction — one invisible plan, one project per camp row.
  class Bootstrap
    class Error < StandardError; end

    DEFAULT_AREA_KEY = "purpose".freeze
    DEFAULT_CATEGORY = "other".freeze
    DEFAULT_COMMITMENT = "easy".freeze
    BOOTSTRAP_FLAG = "onboarding_bootstrap".freeze
    FIRST_CAMP_REVEAL_FLAG = "first_camp_reveal".freeze
    MAX_CAMPS = 20

    Result = Struct.new(:journey, :goal, :plan, :projects, :first_battle, keyword_init: true)

    def self.call(user:, goal_title:, camp_titles:)
      new(user:, goal_title:, camp_titles:).call
    end

    def initialize(user:, goal_title:, camp_titles:)
      @user = user
      @goal_title = goal_title.to_s.strip
      @camp_titles = normalize_camp_titles(camp_titles)
    end

    def call
      raise Error, I18n.t("v2_onboarding.need_goal") if @goal_title.blank?
      raise Error, I18n.t("v2_onboarding.need_camp") if @camp_titles.empty?

      journey = nil
      goal = nil
      plan = nil
      projects = []
      first_battle = nil

      ActiveRecord::Base.transaction do
        areas = LifeAreas::Select.call(user: @user, keys: [ DEFAULT_AREA_KEY ])
        primary_area = areas.find { |a| a.key == DEFAULT_AREA_KEY } || areas.first

        journey = Journeys::Create.call(
          user: @user,
          life_area: primary_area,
          title: @goal_title,
          ideal_scene: I18n.t("v2_onboarding.default_ideal", title: @goal_title),
          current_reality: I18n.t("v2_onboarding.default_reality"),
          next_win: nil,
          closer_percent: 5
        )

        easy = Today::Commitment::PRESETS.fetch(DEFAULT_COMMITMENT)
        journey.update!(
          commitment_key: DEFAULT_COMMITMENT,
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
          # Screen 2 list is nearest-first; trail_y grows toward base camp (climber).
          trail_slot_index = total - 1 - index
          slot = MountainTrailHelper::AutoSlot.call(index: trail_slot_index, total: total)
          projects << create_child!(
            parent: plan,
            horizon: "project",
            title: title,
            life_area: primary_area,
            life_journey: journey,
            position: index,
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
          Onboarding::Categories::CATEGORY_FLAG => DEFAULT_CATEGORY,
          BOOTSTRAP_FLAG => "true",
          FIRST_CAMP_REVEAL_FLAG => "pending"
        )
        journey.update_columns(setup_flags: flags, updated_at: Time.current)
        journey.setup_flags = flags

        @user.update!(onboarding_completed_at: Time.current, planning_version: 2)

        Strategy::Celebrate.call(user: @user, goal: first_battle) if first_battle
      end

      Strategy::PinUnplacedCamps.call(projects: projects)

      Result.new(journey: journey, goal: goal, plan: plan, projects: projects, first_battle: first_battle)
    rescue LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error,
           ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def normalize_camp_titles(camp_titles)
      seen = {}
      Array(camp_titles).map { |t| t.to_s.strip }.reject(&:blank?).each_with_object([]) do |title, list|
        next if seen[title.downcase]

        seen[title.downcase] = true
        list << title
      end.first(MAX_CAMPS)
    end

    def default_seed_battle_title
      Array(I18n.t("strategy.rpg.trail.battle_suggestions")).first.to_s.strip.presence ||
        "Take the first small step"
    end

    def create_child!(parent:, horizon:, title:, life_area:, life_journey:, scheduled_on: nil, position: nil,
                      trail_x: nil, trail_y: nil)
      scope = @user.strategy_goals.where(life_area_id: life_area.id).for_kind(horizon).where(parent_id: parent.id)
      pos = position.nil? ? scope.maximum(:position).to_i + 1 : position
      @user.strategy_goals.create!(
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
    end
  end
end
