# frozen_string_literal: true

module Journeys
  # Complete the summit journey and start a new climb in the same life area.
  class StartNextGoal
    class Error < StandardError; end
    class AlreadyCompleted < StandardError; end

    def self.call(user:, old_journey:, goal_title:, camp_titles:)
      new(user:, old_journey:, goal_title:, camp_titles:).call
    end

    def initialize(user:, old_journey:, goal_title:, camp_titles:)
      @user = user
      @old_journey = old_journey
      @goal_title = goal_title.to_s.strip
      @camp_titles = normalize_camp_titles(camp_titles)
    end

    def call
      raise Error, I18n.t("v2_onboarding.need_goal") if @goal_title.blank?
      raise Error, I18n.t("v2_onboarding.need_camp") if @camp_titles.empty?
      raise Error, "Journey not found" unless @old_journey
      raise Error, "Not your journey" unless @old_journey.user_id == @user.id
      raise AlreadyCompleted if @old_journey.status == "completed"

      unless Strategy::SummitReached.on_journey?(user: @user, journey: @old_journey)
        raise Error, I18n.t("summit_next_goal.not_at_summit")
      end

      area = @old_journey.life_area
      raise Error, I18n.t("summit_next_goal.need_area") if area.blank?

      category = Onboarding::Categories.id_for_journey(@old_journey)

      result = nil
      ActiveRecord::Base.transaction do
        result = Onboarding::ClimbSpine.call(
          user: @user,
          goal_title: @goal_title,
          camp_titles: @camp_titles,
          life_area: area,
          seed_battle: false,
          celebrate_goal: false,
          include_bootstrap_flag: false,
          first_camp_reveal_status: "done",
          setup_category: category
        )

        Complete.call(user: @user, journey: @old_journey)
        Goals::Current.clear_cache!(user: @user)
      end

      result
    rescue Onboarding::ClimbSpine::Error, Complete::Error => e
      raise Error, e.message
    end

    private

    def normalize_camp_titles(camp_titles)
      seen = {}
      Array(camp_titles).map { |t| t.to_s.strip }.reject(&:blank?).each_with_object([]) do |title, list|
        next if seen[title.downcase]

        seen[title.downcase] = true
        list << title
      end.first(Onboarding::Bootstrap::MAX_CAMPS)
    end
  end
end
