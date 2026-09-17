# frozen_string_literal: true

require "test_helper"

module Notifications
  class MorningNudgeCopyTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @date = Date.new(2026, 8, 6)
    end

    test "incomplete battle uses battle title and body with name" do
      @user.daily_todos.create!(
        title: "Ship auth",
        aspect_key: "career",
        scheduled_on: @date,
        position: 0,
        lp_reward: 10
      )

      copy = MorningNudgeCopy.for(user: @user, date: @date, locale: :en)

      assert_equal "Today's battle", copy.title
      assert_equal "Ship auth. Win it today.", copy.body
    end

    test "all battles done today uses plan copy" do
      todo = @user.daily_todos.create!(
        title: "Ship auth",
        aspect_key: "career",
        scheduled_on: @date,
        position: 0,
        lp_reward: 10
      )
      todo.update!(completed_at: Time.zone.local(2026, 8, 6, 9, 0, 0))

      copy = MorningNudgeCopy.for(user: @user, date: @date, locale: :en)

      assert_equal "Plan today", copy.title
      assert_equal "Pick one battle for today.", copy.body
    end

    test "nothing planned uses plan copy" do
      copy = MorningNudgeCopy.for(user: @user, date: @date, locale: :en)

      assert_equal "Plan today", copy.title
      assert_equal "Pick one battle for today.", copy.body
    end
  end
end
