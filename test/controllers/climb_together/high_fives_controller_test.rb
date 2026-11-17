# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  class HighFivesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @viewer = users(:one)
      @partner = users(:two)
      @stranger = users(:admin)
      ClimbPartnership.delete_all
      HighFive.delete_all
      @zone = "Europe/Berlin"
      @partner.create_notification_preference!(time_zone: @zone) unless @partner.notification_preference
      @partner.notification_preference.update!(time_zone: @zone)

      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
        seed_climb!(@viewer)
        seed_climb!(@partner, area_key: "self", today_mission: "Partner win")
        @battle = @partner.strategy_goals.find_by!(horizon: "day", title: "Partner win")
        @battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))
        invite = Invite.call(user: @viewer)
        Accept.call(user: @partner, token: invite.token)
      end
      sign_in_as @viewer
    end

    test "Today hides partner row with no partner" do
      End.call(user: @viewer)
      get dashboard_path

      assert_response :success
      assert_select "#today-partner-row"
      assert_select "#today-partner-row .lp-partner-row", count: 0
    end

    test "Today hides partner row when partner has zero wins" do
      @battle.update!(completed_at: nil)
      get dashboard_path

      assert_response :success
      assert_select "#today-partner-row .lp-partner-row", count: 0
    end

    test "Today shows partner win count and high-five control" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
        get dashboard_path

        assert_response :success
        assert_select "#today-partner-row .lp-partner-row"
        assert_match(
          /#{Regexp.escape(@partner.display_name)} won 1 battle today/i,
          response.body
        )
        assert_select "form.lp-partner-row-form[action=?]", climb_together_high_five_path
      end
    end

    test "cheer creates a high-five and streams the cheered state" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
        assert_difference -> { HighFive.count }, 1 do
          post climb_together_high_five_path, as: :turbo_stream
        end

        assert_response :success
        assert_match(/You cheered #{Regexp.escape(@partner.display_name)}/i, response.body)
        assert_match(/turbo-stream[^>]*target="today-partner-row"/, response.body)
        assert_equal 1, HighFive.where(from_user: @viewer, to_user: @partner).count
      end
    end

    test "second cheer same day does not create another high-five" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
        post climb_together_high_five_path, as: :turbo_stream
        assert_difference -> { HighFive.count }, 0 do
          post climb_together_high_five_path, as: :turbo_stream
        end
        assert_response :success
        assert_match(/You cheered #{Regexp.escape(@partner.display_name)}/i, response.body)
      end
    end

    test "stranger cannot cheer" do
      sign_out
      seed_climb!(@stranger, area_key: "self", today_mission: "Stranger day")
      sign_in_as @stranger

      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
        assert_no_difference -> { HighFive.count } do
          post climb_together_high_five_path, as: :turbo_stream
        end
        assert_response :unprocessable_entity
      end
    end

    test "Today partner day wins query count stays flat with a partner" do
      travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
        queries = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

          queries += 1 if payload[:sql].present?
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          PartnerDayWins.call(viewer: @viewer)
        end

        assert_operator queries, :<=, 6
      end
    end

    test "Today partner day wins query count stays flat without a partner" do
      End.call(user: @viewer)
      queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

        queries += 1 if payload[:sql].present?
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        PartnerDayWins.call(viewer: @viewer)
      end

      assert_operator queries, :<=, 3
    end
  end
end
