# frozen_string_literal: true

module Onboarding
  # New-player onboarding: goal + ordered camps → full spine on Today.
  # All-or-nothing transaction — one invisible plan, one project per camp row.
  class Bootstrap
    class Error < StandardError; end

    DEFAULT_AREA_KEY = "self".freeze
    DEFAULT_CATEGORY = "other".freeze
    DEFAULT_COMMITMENT = "easy".freeze
    BOOTSTRAP_FLAG = "onboarding_bootstrap".freeze
    FIRST_CAMP_REVEAL_FLAG = "first_camp_reveal".freeze
    FIRST_CAMP_ID_FLAG = "first_camp_id".freeze
    FIRST_CAMP_WIN_NUDGE_FLAG = "first_camp_win_nudge".freeze
    MAX_CAMPS = 20

    Result = Struct.new(:journey, :goal, :plan, :projects, :first_battle, keyword_init: true)

    def self.call(user:, goal_title:, camp_titles:, complete_onboarding: true)
      new(user:, goal_title:, camp_titles:, complete_onboarding:).call
    end

    def initialize(user:, goal_title:, camp_titles:, complete_onboarding: true)
      @user = user
      @goal_title = goal_title.to_s.strip
      @camp_titles = normalize_camp_titles(camp_titles)
      @complete_onboarding = complete_onboarding
    end

    def call
      raise Error, I18n.t("v2_onboarding.need_goal") if @goal_title.blank?
      raise Error, I18n.t("v2_onboarding.need_camp") if @camp_titles.empty?

      result = nil

      ActiveRecord::Base.transaction do
        @user.with_lock do
          @user.reload
          if (journey = find_existing_bootstrap_journey)
            ensure_onboarding_completed! if @complete_onboarding
            result = result_for_journey(journey)
          else
            result = ClimbSpine.call(
              user: @user,
              goal_title: @goal_title,
              camp_titles: @camp_titles,
              seed_battle: false
            )

            mark_onboarding_complete! if @complete_onboarding

            Strategy::Celebrate.call(user: @user, goal: result.first_battle) if result.first_battle
            Goals::Current.clear_cache!(user: @user)
          end
        end
      end

      result
    rescue ClimbSpine::Error => e
      raise Error, e.message
    end

    private

    def find_existing_bootstrap_journey
      @user.life_journeys.active.order(id: :desc).find do |journey|
        journey.setup_flag(BOOTSTRAP_FLAG) == "true"
      end
    end

    def result_for_journey(journey)
      plan = @user.strategy_goals.where(life_journey_id: journey.id).for_kind("plan").first
      projects = if plan
        plan.children.for_kind("project").order(:position).to_a
      else
        []
      end
      goal = @user.strategy_goals.where(life_journey_id: journey.id).for_kind("goal").first
      Result.new(journey: journey, goal: goal, plan: plan, projects: projects, first_battle: nil)
    end

    def mark_onboarding_complete!
      return if @user.onboarding_completed? && @user.planning_v2?

      @user.update!(onboarding_completed_at: Time.current, planning_version: 2)
    end

    def ensure_onboarding_completed!
      mark_onboarding_complete!
    end

    def normalize_camp_titles(camp_titles)
      seen = {}
      Array(camp_titles).map { |t| t.to_s.strip }.reject(&:blank?).each_with_object([]) do |title, list|
        next if seen[title.downcase]

        seen[title.downcase] = true
        list << title
      end.first(MAX_CAMPS)
    end
  end
end
