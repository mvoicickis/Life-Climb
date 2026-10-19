# frozen_string_literal: true

module Today
  # Photo Today — single green pill when the battlefield list is empty.
  # No plan → Today shows the first-climb coach, not the battlefield.
  class EmptyBattleCta
    def self.for(journey:, handoff:, first_camp_setup: false)
      new(journey:, handoff:, first_camp_setup:).call
    end

    def initialize(journey:, handoff:, first_camp_setup: false)
      @journey = journey
      @handoff = handoff
      @first_camp_setup = first_camp_setup
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
          label: @handoff&.dig(:label).presence || I18n.t("dash.battlefield.empty_cta.set_goal"),
          href: helpers.life_journey_path(@journey)
        }
      when :summit_next_goal
        {
          label: @handoff&.dig(:label).presence || I18n.t("dash.battlefield.empty_cta.summit_next_goal"),
          href: @handoff&.dig(:href) || helpers.summit_next_goal_path
        }
      when :add_project
        {
          label: I18n.t("dash.battlefield.empty_cta.add_next_camp"),
          href: helpers.life_journey_path(@journey, open_plant: 1)
        }
      when :add_battle, :open_strategy
        camp_id =
          project_id.presence ||
          Strategy::PathProject.resolve(user: @journey.user, journey: @journey)&.id
        mountain_params = {
          open_camp: camp_id,
          open_composer: 1
        }
        if @first_camp_setup && @journey.first_camp_reveal_pending?
          mountain_params[:first_camp_setup] = 1
        end
        {
          label: I18n.t("dash.battlefield.empty_cta.add_todays_battle"),
          href: helpers.life_journey_path(@journey, **mountain_params)
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
