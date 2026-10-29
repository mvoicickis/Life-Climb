# frozen_string_literal: true

require "test_helper"

class LifeAreas::SelectTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
  end

  test "selecting one area creates a v2 row and sets planning_version" do
    @user.update!(planning_version: 1)
    assert_equal 1, @user.planning_version

    areas = LifeAreas::Select.call(user: @user, keys: %w[career])

    assert_equal 1, areas.size
    assert_equal "career", areas.first.key
    assert areas.first.v2_selected?
    assert_nil areas.first.dream_id
    assert @user.reload.planning_v2?
    assert_equal 2, @user.planning_version
  end

  test "rejects selecting more than one area" do
    assert_raises LifeAreas::Select::Error do
      LifeAreas::Select.call(user: @user, keys: LifeArea::CATALOG_KEYS)
    end
  end

  test "calling twice with the same key returns the same row" do
    first = LifeAreas::Select.call(user: @user, keys: %w[purpose]).first
    second = LifeAreas::Select.call(user: @user, keys: %w[purpose]).first

    assert_equal first.id, second.id
    assert_equal 1, @user.life_areas.where(dream_id: nil, key: "purpose").count
  end

  test "selecting another area keeps previous selected without touching legacy dream areas" do
    legacy_count = @user.life_areas.where.not(dream_id: nil).count
    assert legacy_count.positive?

    LifeAreas::Select.call(user: @user, keys: %w[self])
    LifeAreas::Select.call(user: @user, keys: %w[purpose])

    selected = @user.life_areas.v2_selected
    assert_equal %w[self purpose].sort, selected.map(&:key).sort
    assert_equal legacy_count, @user.life_areas.where.not(dream_id: nil).count
    assert @user.life_areas.find_by(key: "self", dream_id: nil).v2_selected?
    assert @user.life_areas.find_by(key: "purpose", dream_id: nil).v2_selected?
  end

  test "selecting area B keeps focus_position on journeys in A" do
    LifeAreas::Select.call(user: @user, keys: %w[career])
    area_a = @user.life_areas.v2_selected.find_by!(key: "career")
    journey = Journeys::Create.call(
      user: @user,
      life_area: area_a,
      title: "Career climb",
      ideal_scene: "Ideal career",
      current_reality: "Present career",
      next_win: "Next career",
      closer_percent: 20
    )
    Focus::SetJourneys.call(user: @user, journey_ids: [ journey.id ])
    assert_equal 1, journey.reload.focus_position

    LifeAreas::Select.call(user: @user, keys: %w[purpose])

    assert_equal 1, journey.reload.focus_position
    assert_equal %w[career purpose].sort, @user.life_areas.v2_selected.pluck(:key).sort
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
