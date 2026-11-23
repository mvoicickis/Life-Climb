# frozen_string_literal: true

module Onboarding
  # First-camp day battles for v3 onboarding — idempotent if battles already exist.
  class PlantBattles
    class Error < StandardError; end

    def self.call(user:, journey:, battle_titles:)
      new(user:, journey:, battle_titles:).call
    end

    def initialize(user:, journey:, battle_titles:)
      @user = user
      @journey = journey
      @battle_titles = normalize_titles(battle_titles)
    end

    def call
      raise Error, I18n.t("v2_onboarding.need_battle") if @battle_titles.empty?

      project = first_camp_project
      raise Error, I18n.t("v2_onboarding.need_camp") if project.blank?

      existing = project.children.for_kind("day").reject(&:holding?)
      return existing if existing.any?

      created = []
      ActiveRecord::Base.transaction do
        @battle_titles.each do |title|
          created << Strategy::CreateDayBattle.call(user: @user, project: project, title: title)
        end
        @journey.set_first_camp_win_nudge!
      end

      created
    end

    private

    def first_camp_project
      camp_id = @journey.setup_flag(Bootstrap::FIRST_CAMP_ID_FLAG).to_i
      return if camp_id.blank?

      @user.strategy_goals
        .where(life_journey_id: @journey.id)
        .for_kind("project")
        .not_holding
        .find_by(id: camp_id)
    end

    def normalize_titles(titles)
      seen = {}
      Array(titles).map { |t| t.to_s.strip }.reject(&:blank?).each_with_object([]) do |title, list|
        key = title.downcase
        next if seen[key]

        seen[key] = true
        list << title
      end.first(5)
    end
  end
end
