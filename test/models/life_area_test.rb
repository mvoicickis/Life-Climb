require "test_helper"

class LifeAreaTest < ActiveSupport::TestCase
  test "catalog has thirteen keys" do
    assert_equal 13, LifeArea::CATALOG_KEYS.size
  end

  test "v2 selected area uses catalog label" do
    user = users(:one)
    area = user.life_areas.create!(
      key: "creativity",
      number: LifeArea.catalog_number("creativity"),
      position: 0,
      selected_at: Time.current,
      dream_id: nil,
      closer_score: 1,
      meta: {}
    )

    assert_equal I18n.t("life_area_catalog.creativity.name"), area.label
    assert area.v2_selected?
  end

  test "legacy dream areas still validate against KEYS" do
    area = life_areas(:one_self)
    assert_includes LifeArea::KEYS, area.key
    assert area.valid?
  end

  test "cannot destroy area while journeys exist" do
    user = users(:one)
    area = user.life_areas.create!(
      key: "purpose",
      number: LifeArea.catalog_number("purpose"),
      position: 0,
      selected_at: Time.current,
      dream_id: nil,
      closer_score: 1,
      meta: {}
    )
    user.life_journeys.create!(
      life_area: area,
      title: "Climb",
      ideal_scene: "Summit",
      current_reality: "Base camp",
      status: "active"
    )

    assert_not area.destroy
    assert area.errors[:base].present?
    assert LifeArea.exists?(area.id)
  end

  test "WORLD_RINGS has four unique values" do
    assert_equal %w[me family_friends work_money creativity], LifeArea::WORLD_RINGS
    assert_equal LifeArea::WORLD_RINGS, LifeArea::WORLD_RINGS.uniq
  end

  test "every catalog and legacy key maps to one of the four rings" do
    (LifeArea::CATALOG_KEYS + LifeArea::KEYS).uniq.each do |key|
      ring = LifeArea.world_ring_for(key)
      assert_includes LifeArea::WORLD_RINGS, ring, "#{key} should map to a world ring"
    end
    LifeArea::WORLD_RING_BY_KEY.each_key do |key|
      ring = LifeArea.world_ring_for(key)
      assert_includes LifeArea::WORLD_RINGS, ring, "#{key} should map to a world ring"
    end
  end

  test "world ring mapping for me" do
    assert_equal "me", LifeArea.world_ring_for("self")
    assert_equal "me", LifeArea.world_ring_for("learning")
    assert_equal "me", LifeArea.world_ring_for("purpose")
  end

  test "world ring mapping for family_friends" do
    assert_equal "family_friends", LifeArea.world_ring_for("relationships")
    assert_equal "family_friends", LifeArea.world_ring_for("family")
    assert_equal "family_friends", LifeArea.world_ring_for("love")
    assert_equal "family_friends", LifeArea.world_ring_for("community")
    assert_equal "family_friends", LifeArea.world_ring_for("humanity")
  end

  test "world ring mapping for work_money" do
    assert_equal "work_money", LifeArea.world_ring_for("career")
    assert_equal "work_money", LifeArea.world_ring_for("money")
    assert_equal "work_money", LifeArea.world_ring_for("home")
    assert_equal "work_money", LifeArea.world_ring_for("physical_world")
  end

  test "world ring mapping for creativity" do
    assert_equal "creativity", LifeArea.world_ring_for("creativity")
    assert_equal "creativity", LifeArea.world_ring_for("animals")
    assert_equal "creativity", LifeArea.world_ring_for("nature")
  end

  test "world_ring_for unknown or nil falls back to me" do
    assert_equal "me", LifeArea.world_ring_for(nil)
    assert_equal "me", LifeArea.world_ring_for("spaceships")
  end

  test "instance world_ring uses key" do
    area = life_areas(:one_self)
    assert_equal LifeArea.world_ring_for(area.key), area.world_ring
  end

  test "key_for_ring maps all four creatable rings" do
    assert_equal "self", LifeArea.key_for_ring("me")
    assert_equal "relationships", LifeArea.key_for_ring("family_friends")
    assert_equal "career", LifeArea.key_for_ring("work_money")
    assert_equal "creativity", LifeArea.key_for_ring("creativity")
    assert_nil LifeArea.key_for_ring("infinity")
    assert_nil LifeArea.key_for_ring("family_love")
    assert_nil LifeArea.key_for_ring("spaceships")
    assert_nil LifeArea.key_for_ring(nil)
    assert_equal LifeArea::WORLD_RINGS, LifeArea.creatable_world_rings
    assert_equal 4, LifeArea.creatable_world_rings.size
  end
end
