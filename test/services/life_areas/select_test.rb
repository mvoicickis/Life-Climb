require "test_helper"

class LifeAreas::SelectTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
  end

  test "selecting one area creates a v2 row and sets planning_version" do
    assert_equal 1, @user.planning_version

    areas = LifeAreas::Select.call(user: @user, keys: %w[career])

    assert_equal 1, areas.size
    assert_equal "career", areas.first.key
    assert areas.first.v2_selected?
    assert_nil areas.first.dream_id
    assert @user.reload.planning_v2?
    assert_equal 2, @user.planning_version
  end

  test "selecting all catalog keys works" do
    areas = LifeAreas::Select.call(user: @user, keys: LifeArea::CATALOG_KEYS)

    assert_equal LifeArea::CATALOG_KEYS.size, areas.size
    assert_equal LifeArea::CATALOG_KEYS, areas.map(&:key)
  end

  test "reselecting replaces previous v2 selection without touching legacy dream areas" do
    legacy_count = @user.life_areas.where.not(dream_id: nil).count
    assert legacy_count.positive?

    LifeAreas::Select.call(user: @user, keys: %w[self career])
    LifeAreas::Select.call(user: @user, keys: %w[purpose])

    selected = @user.life_areas.v2_selected
    assert_equal [ "purpose" ], selected.map(&:key)
    assert_equal legacy_count, @user.life_areas.where.not(dream_id: nil).count
  end

  test "rejects empty selection" do
    assert_raises LifeAreas::Select::Error do
      LifeAreas::Select.call(user: @user, keys: [])
    end
  end

  test "rejects unknown keys" do
    assert_raises LifeAreas::Select::Error do
      LifeAreas::Select.call(user: @user, keys: %w[career spaceships])
    end
  end

  test "catalog i18n keys exist" do
    LifeArea::CATALOG_KEYS.each do |key|
      assert I18n.exists?("life_area_catalog.#{key}.name"), "missing name for #{key}"
      assert I18n.exists?("life_area_catalog.#{key}.hint"), "missing hint for #{key}"
    end
  end
end
