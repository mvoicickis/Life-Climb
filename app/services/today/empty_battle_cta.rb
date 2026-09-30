# frozen_string_literal: true

module Today
  # Photo Today — single green pill when the battlefield list is empty.
  class EmptyBattleCta
    def self.for(journey:, handoff:)
      new(journey:, handoff:).call
    end

    def initialize(journey:, handoff:)
      @journey = journey
      @handoff = handoff
    end

    def call
      helpers = Rails.application.routes.url_helpers

      if @journey.blank?
        return {
          label: I18n.t("dash.battlefield.empty_cta.start_climb"),
          href: helpers.new_life_journey_path
        }
      end

      step = @handoff&.dig(:step)
      project_id = @handoff&.dig(:project_id)

      case step
      when :lock_goal
        {
          label: I18n.t("dash.battlefield.empty_cta.set_goal"),
          href: helpers.life_journey_path(@journey)
        }
      when :add_plan
        {
          label: I18n.t("dash.battlefield.empty_cta.open_mountain"),
          href: helpers.life_journey_path(@journey, notebook: 1)
        }
      when :add_project
        {
          label: I18n.t("dash.battlefield.empty_cta.add_next_camp"),
          href: helpers.life_journey_path(@journey, open_plant: 1)
        }
      when :add_battle, :open_strategy
        {
          label: I18n.t("dash.battlefield.empty_cta.add_todays_battle"),
          href: helpers.life_journey_path(
            @journey,
            open_camp: project_id,
            open_composer: 1
          )
        }
      else
        {
          label: I18n.t("dash.battlefield.empty_cta.start_climb"),
          href: helpers.new_life_journey_path
        }
      end
    end
  end
end
