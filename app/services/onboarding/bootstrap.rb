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
    FIRST_CAMP_ID_FLAG = "first_camp_id".freeze
    FIRST_CAMP_WIN_NUDGE_FLAG = "first_camp_win_nudge".freeze
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

      result = nil

      ActiveRecord::Base.transaction do
        result = ClimbSpine.call(
          user: @user,
          goal_title: @goal_title,
          camp_titles: @camp_titles
        )

        @user.update!(onboarding_completed_at: Time.current, planning_version: 2)

        Strategy::Celebrate.call(user: @user, goal: result.first_battle) if result.first_battle
        Goals::Current.clear_cache!(user: @user)
      end

      result
    rescue ClimbSpine::Error => e
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
  end
end
