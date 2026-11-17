# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  module HighFives
    class CreateTest < ActiveJob::TestCase
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

      test "cheer enqueues exactly one high_five push with title body url kind" do
        @from.update!(avatar_key: nil)

        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          assert_enqueued_jobs 1, only: SendWebPushJob do
            Create.call(from: @from, battle: @battle)
          end

          job = enqueued_jobs.find { |j| j["job_class"] == "SendWebPushJob" }
          assert job
          user_id, payload = ActiveJob::Arguments.deserialize(job["arguments"])
          assert_equal @to.id, user_id
          assert_equal "#{@from.display_name} 🙌", payload["title"]
          assert_equal(
            "#{@from.display_name} high-fived your battle: Partner battle",
            payload["body"]
          )
          assert_equal "/dashboard", payload["url"]
          assert_equal "high_five", payload["kind"]
          assert_equal "high_five", payload["tag"]
          refute payload.key?("icon")
        end
      end

      test "repeat cheer same day enqueues no push" do
        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          Create.call(from: @from, battle: @battle)
          clear_enqueued_jobs

          assert_no_enqueued_jobs only: SendWebPushJob do
            assert_raises(ClimbTogether::Error) do
              Create.call(from: @from, battle: @battle)
            end
          end
        end
      end

      test "push body truncates a long battle title" do
        long = "A" * 80
        @battle.update!(title: long)

        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          assert_enqueued_with(job: SendWebPushJob) do
            Create.call(from: @from, battle: @battle)
          end

          job = enqueued_jobs.find { |j| j["job_class"] == "SendWebPushJob" }
          _user_id, payload = ActiveJob::Arguments.deserialize(job["arguments"])
          truncated = Notifications::PushGoalTitle.truncate(long, limit: 60)
          assert_equal truncated, long[0, 60] + "…"
          assert_includes payload["body"], truncated
          refute_includes payload["body"], long
        end
      end

      test "push icon uses sender animal avatar when set" do
        @from.update!(avatar_key: "fox")

        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          Create.call(from: @from, battle: @battle)

          job = enqueued_jobs.find { |j| j["job_class"] == "SendWebPushJob" }
          _user_id, payload = ActiveJob::Arguments.deserialize(job["arguments"])
          assert payload["icon"].present?
          assert_match(%r{\Ahttps://}, payload["icon"])
          assert_includes payload["icon"], "avatars/fox"
        end
      end

      test "enqueue error does not break the cheer" do
        original = SendWebPushJob.method(:perform_later)
        SendWebPushJob.define_singleton_method(:perform_later) do |*_args|
          raise StandardError, "queue down"
        end

        travel_to Time.find_zone!(@zone).local(2026, 11, 17, 14, 0, 0) do
          assert_difference -> { HighFive.count }, 1 do
            high_five = Create.call(from: @from, battle: @battle)
            assert_equal @battle, high_five.strategy_goal
          end
        end
      ensure
        SendWebPushJob.define_singleton_method(:perform_later, original)
      end
    end
  end
end
