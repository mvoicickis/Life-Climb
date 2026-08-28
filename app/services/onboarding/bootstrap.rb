# frozen_string_literal: true

module Onboarding
  # New-player onboarding: goal + camp + today's battles → full spine on Today.
  # All-or-nothing transaction — no route mission, no destination overlay dead end.
  class Bootstrap
    class Error < StandardError; end

    DEFAULT_AREA_KEY = "purpose".freeze
    DEFAULT_CATEGORY = "other".freeze
    DEFAULT_COMMITMENT = "easy".freeze
    BOOTSTRAP_FLAG = "onboarding_bootstrap".freeze
    MAX_BATTLES = 5

    Result = Struct.new(:journey, :goal, :plan, :project, :battles, keyword_init: true)

    def self.call(user:, goal_title:, camp_title:, battle_titles:)
      new(user:, goal_title:, camp_title:, battle_titles:).call
    end

    def initialize(user:, goal_title:, camp_title:, battle_titles:)
      @user = user
      @goal_title = goal_title.to_s.strip
      @camp_title = camp_title.to_s.strip
      @battle_titles = Array(battle_titles).map { |t| t.to_s.strip }.reject(&:blank?).first(MAX_BATTLES)
    end

    def call
      raise Error, I18n.t("v2_onboarding.need_goal") if @goal_title.blank?
      raise Error, I18n.t("v2_onboarding.need_camp") if @camp_title.blank?
      raise Error, I18n.t("v2_onboarding.need_battle") if @battle_titles.empty?

      journey = nil
      goal = nil
      plan = nil
      project = nil
      battles = []

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

        key = DEFAULT_COMMITMENT
        unless Today::Commitment.eligible_for?(user: @user, key: key, journey: journey)
          key = "easy"
        end
        Today::Commitment.apply_preset!(journey, key)
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
          title: @camp_title,
          life_area: primary_area,
          life_journey: journey
        )
        project = create_child!(
          parent: plan,
          horizon: "project",
          title: I18n.t("strategy.first_climb.project_title", plan: @camp_title.truncate(40)),
          life_area: primary_area,
          life_journey: journey
        )

        @battle_titles.each_with_index do |title, index|
          battles << create_child!(
            parent: project,
            horizon: "day",
            title: title,
            life_area: primary_area,
            life_journey: journey,
            scheduled_on: Date.current,
            position: index
          )
        end

        Strategy::CascadeToDaily.call(user: @user, life_area: primary_area)

        flags = (journey.setup_flags.presence || {}).stringify_keys.merge(
          Onboarding::Categories::CATEGORY_FLAG => DEFAULT_CATEGORY,
          BOOTSTRAP_FLAG => "true"
        )
        journey.update_columns(setup_flags: flags, updated_at: Time.current)
        journey.setup_flags = flags

        @user.update!(onboarding_completed_at: Time.current, planning_version: 2)

        first_battle = battles.first
        Strategy::Celebrate.call(user: @user, goal: first_battle) if first_battle
      end

      Result.new(journey: journey, goal: goal, plan: plan, project: project, battles: battles)
    rescue LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error,
           ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def create_child!(parent:, horizon:, title:, life_area:, life_journey:, scheduled_on: nil, position: nil)
      scope = @user.strategy_goals.where(life_area_id: life_area.id).for_kind(horizon).where(parent_id: parent.id)
      pos = position.nil? ? scope.maximum(:position).to_i + 1 : position
      @user.strategy_goals.create!(
        life_area: life_area,
        life_journey: life_journey,
        parent: parent,
        horizon: horizon,
        title: title,
        scheduled_on: scheduled_on,
        position: pos
      )
    end
  end
end
