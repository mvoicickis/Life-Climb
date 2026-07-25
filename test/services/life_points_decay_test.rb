require "test_helper"

class LifePointsDecayTest < ActiveSupport::TestCase
  test "decays points after idle days once per day" do
    user = users(:one)
    user.update!(total_points: 40, created_at: 10.days.ago)

    assert_difference -> { user.reload.total_points }, -5 do
      LifePointsDecay.new(user).call
    end

    assert_no_difference -> { user.reload.total_points } do
      LifePointsDecay.new(user).call
    end
  end

  test "skips when recently active" do
    user = users(:one)
    user.update!(total_points: 40)
    user.life_point_ledgers.create!(amount: 10, reason: "recent", source_type: "TodayAction", source_id: 1)

    assert_no_difference -> { user.reload.total_points } do
      LifePointsDecay.new(user).call
    end
  end
end
