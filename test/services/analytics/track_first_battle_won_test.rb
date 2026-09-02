# frozen_string_literal: true

require "test_helper"

class Analytics::TrackFirstBattleWonTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Ship the form")
    @todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Ship the form")
    @session = {}
  end

  test "emits first_battle_won once after first completion" do
    assert_difference -> { @user.user_events.named("first_battle_won").count }, 1 do
      Battles::CompleteTodo.call(todo: @todo, user: @user, session: @session)
    end

    assert_no_difference -> { @user.user_events.named("first_battle_won").count } do
      Analytics::TrackFirstBattleWon.call(user: @user.reload)
    end
  end

  test "does not emit before any battle is won" do
    assert_no_difference -> { @user.user_events.named("first_battle_won").count } do
      Analytics::TrackFirstBattleWon.call(user: @user)
    end
  end
end
