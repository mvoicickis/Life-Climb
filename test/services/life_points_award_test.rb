require "test_helper"

class LifePointsAwardTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @action = today_actions(:one)
  end

  test "completing an action awards weighted life points" do
    @action.update!(completed_at: nil)
    assert_difference -> { @user.reload.total_points }, LifePointsAward::ACTION do
      LifePointsAward.new(@user).for_action!(@action)
    end
    assert @user.life_point_ledgers.where(source: @action).exists?
  end

  test "finished product awards much more than an action" do
    assert LifePointsAward::FINISHED_PRODUCT >= LifePointsAward::ACTION * 50
  end

  test "shipping a building creates finished product and awards creation points" do
    building = buildings(:one)
    product = nil
    expected = LifePointsAward::BUILDING_SHIP + LifePointsAward::FINISHED_PRODUCT

    assert_difference -> { @user.reload.total_points }, expected do
      product = ShipBuilding.new(building: building, value_summary: "Helps people build a more alive life").call
    end

    assert product.persisted?
    assert_equal "shipped", building.reload.status
    assert_equal expected, @user.life_point_ledgers.where(source_type: %w[Building FinishedProduct]).sum(:amount)
  end
end
