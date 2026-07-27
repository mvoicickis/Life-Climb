# frozen_string_literal: true

require "test_helper"

class ClimbPersonalBestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(best_day_ap: 40)
    @user.life_point_ledgers.delete_all
  end

  test "records a personal best when today beats prior best" do
    @user.life_point_ledgers.create!(amount: 50, reason: "Battle")
    result = Climb::PersonalBest.record!(user: @user, awarded: 50)
    assert result.new_record
    assert_equal 50, @user.reload.best_day_ap
  end

  test "does not flag personal best when below prior best" do
    @user.life_point_ledgers.create!(amount: 20, reason: "Battle")
    result = Climb::PersonalBest.record!(user: @user, awarded: 20)
    assert_not result.new_record
    assert_equal 40, @user.reload.best_day_ap
  end
end
