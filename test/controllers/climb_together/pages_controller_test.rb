# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  class PagesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @viewer = users(:one)
      @partner = users(:two)
      ClimbPartnership.delete_all
      HighFive.delete_all
      @zone = "Europe/Berlin"
      @viewer.create_notification_preference!(time_zone: @zone) unless @viewer.notification_preference
      @viewer.notification_preference.update!(time_zone: @zone)
      @partner.create_notification_preference!(time_zone: @zone) unless @partner.notification_preference
      @partner.notification_preference.update!(time_zone: @zone)
      sign_in_as @viewer
    end

    test "redirects to You when there is no active partner" do
      get climb_together_path

      assert_redirected_to settings_path
    end

    test "shows both cards with camps and wins and hides open battle titles" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@viewer, today_mission: "Viewer open secret")
        seed_climb!(@partner, area_key: "self", today_mission: "Partner open secret")
        allow_extra_climbs!(@partner)
        journey = @partner.primary_focused_journey
        project = @partner.strategy_goals.for_kind("project").where(life_journey_id: journey.id).first
        won = add_todays_battle!(
          user: @partner,
          project: project,
          journey: journey,
          title: "Partner weekly win"
        )
        won.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))

        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        get climb_together_path

        assert_response :success
        assert_select "#climb-together-side"
        assert_select ".lp-side-mtn__name", text: I18n.t("climb_together.side.you")
        assert_select ".lp-side-mtn__name", text: @partner.display_name
        assert_match(/Camp \d+ of \d+/, response.body)
        assert_match(/1 win this week/, response.body)
        assert_select ".lp-side__cta", text: I18n.t("climb_together.side.back_to_today")
        refute_match(/Viewer open secret/, response.body)
        refute_match(/Partner open secret/, response.body)
      end
    end

    test "partner without a goal renders picking a mountain" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@viewer, today_mission: "Viewer day")
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)
        @partner.life_journeys.update_all(status: "archived", focus_position: nil)

        get climb_together_path

        assert_response :success
        assert_select ".lp-side-mtn__camp", text: I18n.t("climb_together.side.picking_mountain")
      end
    end

    test "Today partner text links to side by side and cheer still posts high-five" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@viewer, today_mission: "Viewer day")
        seed_climb!(@partner, area_key: "self", today_mission: "Partner win")
        battle = @partner.strategy_goals.find_by!(horizon: "day", title: "Partner win")
        battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)

        get dashboard_path
        assert_response :success
        assert_select "#today-partner-row a.lp-partner-row__link[href=?]", climb_together_path
        assert_select "form.lp-partner-row-form[action=?]", climb_together_high_five_path

        assert_difference -> { HighFive.count }, 1 do
          post climb_together_high_five_path, as: :turbo_stream
        end
        assert_response :success
      end
    end
  end
end
