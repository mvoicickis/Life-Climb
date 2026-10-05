# frozen_string_literal: true

require "test_helper"

module Stats
  class FinishedPathCampsTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(
        name: "Path camps",
        email_address: "path-camps-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345",
        planning_version: 2,
        onboarding_completed_at: Time.current
      )
    end

    test "finished scope sql filters project camps with plan parent" do
      sql = FinishedPathCamps.finished_scope(user: @user).to_sql
      assert_includes sql, '"strategy_goals"."horizon" = \'project\''
      assert_includes sql, '"parents"."horizon" = \'plan\''
    end

    test "counts path camp finished through climb spine" do
      result = Onboarding::ClimbSpine.call(
        user: @user,
        goal_title: "Spine goal",
        camp_titles: [ "Trail camp" ]
      )
      camp = result.projects.first
      assert camp.path_level_camp?, "expected path-level camp from spine"

      camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
      camp.complete!

      assert_equal 1, FinishedPathCamps.total_count(user: @user)
      assert_equal 1, FinishedPathCamps.completion_dates(user: @user, time_zone: "UTC").size
    end
  end
end
