# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  module HighFives
    class CreateTest < ActiveSupport::TestCase
      setup do
        @from = users(:one)
        @to = users(:two)
        @stranger = users(:admin)
        ClimbPartnership.delete_all
        HighFive.delete_all

        @zone = "Europe/Berlin"
        @to.create_notification_preference!(time_zone: @zone) unless @to.notification_preference
        @to.notification_preference.update!(time_zone: @zone)

        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
          seed_climb!(@to, today_mission: "Partner battle")
        end
        @battle = @to.strategy_goals.find_by!(horizon: "day", title: "Partner battle")
        @battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))

        invite = Invite.call(user: @from)
        Accept.call(user: @to, token: invite.token)
      end

      test "happy path creates a high-five for a won partner battle" do
        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          high_five = Create.call(from: @from, battle: @battle)

          assert_equal @from, high_five.from_user
          assert_equal @to, high_five.to_user
          assert_equal @battle, high_five.strategy_goal
          assert_nil high_five.daily_todo_id
        end
      end

      test "rejects a stranger with no partnership" do
        End.call(user: @from)

        error = assert_raises(ClimbTogether::Error) do
          Create.call(from: @from, battle: @battle)
        end
        assert_match(/not active partners/i, error.message)
      end

      test "rejects a battle owned by someone who is not the partner" do
        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 12, 0, 0) do
          seed_climb!(@stranger, area_key: "self", today_mission: "Stranger battle")
        end
        other_battle = @stranger.strategy_goals.find_by!(horizon: "day", title: "Stranger battle")
        other_battle.update!(completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 9, 0, 0))

        error = assert_raises(ClimbTogether::Error) do
          Create.call(from: @from, battle: other_battle)
        end
        assert_match(/not active partners/i, error.message)
      end

      test "rejects a daily todo that does not belong to the battle" do
        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          orphan = @to.daily_todos.create!(
            title: "Unrelated",
            aspect_key: "career",
            scheduled_on: Date.new(2026, 11, 17),
            completed_at: Time.find_zone!(@zone).local(2026, 11, 17, 10, 0, 0)
          )

          error = assert_raises(ClimbTogether::Error) do
            Create.call(from: @from, battle: @battle, daily_todo: orphan)
          end
          assert_match(/does not match/i, error.message)
        end
      end

      test "rejects an unwon battle" do
        @battle.update!(completed_at: nil)

        error = assert_raises(ClimbTogether::Error) do
          Create.call(from: @from, battle: @battle)
        end
        assert_match(/not won/i, error.message)
      end

      test "rejects a second high-five for the same battle on the partner local day" do
        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          Create.call(from: @from, battle: @battle)

          error = assert_raises(ClimbTogether::Error) do
            Create.call(from: @from, battle: @battle)
          end
          assert_match(/already high-fived/i, error.message)
        end
      end

      test "WinsOnLocalDate.count_for_date returns the partner count not yours" do
        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          @from.daily_todos.delete_all
          # Ensure from has no wins today.
          @from.strategy_goals.battles.update_all(completed_at: nil)

          date = Date.new(2026, 11, 17)
          partner_count = Battles::WinsOnLocalDate.count_for_date(
            user: @to, date: date, time_zone: @zone
          )
          own_count = Battles::WinsOnLocalDate.count_for_date(
            user: @from, date: date, time_zone: Battles::WinsOnLocalDate.time_zone_for(@from)
          )

          assert_equal 1, partner_count
          assert_equal 0, own_count
        end
      end
    end
  end
end
