# frozen_string_literal: true

require "test_helper"

class AreaTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "requires name and belongs to user" do
    area = @user.areas.build(name: "")
    assert_not area.valid?
    assert_includes area.errors[:name], "can't be blank"

    area.name = "Finance"
    assert area.save
    assert_equal @user.id, area.user_id
    assert area.position.positive?
  end

  test "ordered by position then id" do
    b = @user.areas.create!(name: "B", position: 2)
    a = @user.areas.create!(name: "A", position: 1)
    assert_equal [ a.id, b.id ], @user.areas.ordered.pluck(:id)
  end

  test "destroying area nullifies habit area_id" do
    area = @user.areas.create!(name: "Health")
    habit = habits(:one)
    habit.update!(area: area, state: "good")

    area.destroy!
    habit.reload
    assert_nil habit.area_id
    assert_nil habit.state
  end
end
