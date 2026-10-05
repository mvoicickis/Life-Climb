# frozen_string_literal: true

require "test_helper"

module Stats
  class GoalsReachedTest < ActiveSupport::TestCase
    setup do
      Goals::Current.clear_cache!
      @user = User.create!(
        name: "Reached",
        email_address: "goals-reached-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345",
        planning_version: 2,
        onboarding_completed_at: Time.current
      )
      @zone = "UTC"
      @user.create_notification_preference!(time_zone: @zone)
    end

    teardown do
      Goals::Current.clear_cache!
    end

    test "all finished path camps counts active journey without completed journeys" do
      bootstrap = Onboarding::Bootstrap.call(
        user: @user,
        goal_title: "Active climb",
        camp_titles: %w[Alpha Beta]
      )
      plan = bootstrap.plan
      finish_camp!(bootstrap.projects.first)
      finish_camp!(bootstrap.projects.second)

      result = GoalsReached.call(user: @user)
      assert_equal 2, result.all_finished_path_camps
      assert result.any_finished_path_camp
      assert_not result.any_completed_journey
      assert_empty result.rows
    end

    test "rows newest first with goal title and camp counts" do
      travel_to Time.zone.local(2026, 10, 1, 12, 0, 0) do
        complete_journey!(goal_title: "Older goal", camp_titles: [ "A" ])
        travel 2.days
        complete_journey!(goal_title: "Newer goal", camp_titles: %w[B C])

        result = GoalsReached.call(user: @user.reload)
        assert_equal 2, result.rows.size
        assert_equal "Newer goal", result.rows.first.title
        assert_equal "Older goal", result.rows.second.title
        assert_equal 2, result.rows.first.camps_count
        assert_equal 1, result.rows.second.camps_count
        assert result.rows.first.completed_on.present?
      end
    end

    test "row title falls back to journey title when root goal missing" do
      bootstrap = Onboarding::Bootstrap.call(user: @user, goal_title: "Fallback", camp_titles: [ "A" ])
      finish_all_camps!(bootstrap.plan)
      Journeys::Complete.call(user: @user, journey: bootstrap.journey)
      bootstrap.goal.destroy!

      row = GoalsReached.call(user: @user.reload).rows.first
      assert_equal "Fallback", row.title
    end

    test "call uses same query count for one and ten completed journeys" do
      count_queries = lambda do
        queries = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          next if payload[:cached]
          next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

          queries += 1 if payload[:sql].present?
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          GoalsReached.call(user: @user.reload)
        end
        queries
      end

      complete_journey!(goal_title: "One", camp_titles: [ "A" ])
      one = count_queries.call

      9.times do |i|
        complete_journey!(goal_title: "Extra #{i}", camp_titles: [ "Camp" ])
      end
      ten = count_queries.call

      assert_equal one, ten, "expected batched queries (1=#{one}, 10=#{ten})"
    end

    private

    def finish_camp!(camp)
      camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
      camp.complete!
    end

    def finish_all_camps!(plan)
      plan.children.for_kind("project").each { |camp| finish_camp!(camp) }
    end

    def complete_journey!(goal_title:, camp_titles:)
      bootstrap = Onboarding::Bootstrap.call(
        user: @user,
        goal_title: goal_title,
        camp_titles: camp_titles
      )
      finish_all_camps!(bootstrap.plan)
      Journeys::Complete.call(user: @user, journey: bootstrap.journey)
      Goals::Current.clear_cache!(user: @user)
      bootstrap.journey
    end
  end
end
