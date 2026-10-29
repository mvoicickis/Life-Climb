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

  test "WORLD_RINGS has eight unique values" do
    assert_equal 8, LifeArea::WORLD_RINGS.size
    assert_equal LifeArea::WORLD_RINGS, LifeArea::WORLD_RINGS.uniq
  end

  test "every catalog and legacy key maps to a world ring" do
    (LifeArea::CATALOG_KEYS + LifeArea::KEYS).uniq.each do |key|
      ring = LifeArea.world_ring_for(key)
      assert_includes LifeArea::WORLD_RINGS, ring, "#{key} should map to a world ring"
    end
  end

  test "world ring mapping for me" do
    assert_equal "me", LifeArea.world_ring_for("self")
    assert_equal "me", LifeArea.world_ring_for("learning")
    assert_equal "me", LifeArea.world_ring_for("creativity")
  end

  test "world ring mapping for family_love" do
    assert_equal "family_love", LifeArea.world_ring_for("relationships")
    assert_equal "family_love", LifeArea.world_ring_for("family")
    assert_equal "family_love", LifeArea.world_ring_for("love")
  end

  test "world ring mapping for friends_work" do
    assert_equal "friends_work", LifeArea.world_ring_for("career")
  end

  test "world ring mapping for people" do
    assert_equal "people", LifeArea.world_ring_for("community")
    assert_equal "people", LifeArea.world_ring_for("humanity")
  end

  test "world ring mapping for animals_nature" do
    assert_equal "animals_nature", LifeArea.world_ring_for("animals")
    assert_equal "animals_nature", LifeArea.world_ring_for("nature")
  end

  test "world ring mapping for things_money" do
    assert_equal "things_money", LifeArea.world_ring_for("money")
    assert_equal "things_money", LifeArea.world_ring_for("home")
    assert_equal "things_money", LifeArea.world_ring_for("physical_world")
  end

  test "world ring mapping for spirit" do
    assert_equal "spirit", LifeArea.world_ring_for("purpose")
  end

  test "world_ring_for unknown or nil falls back to me" do
    assert_equal "me", LifeArea.world_ring_for(nil)
    assert_equal "me", LifeArea.world_ring_for("spaceships")
  end

  test "instance world_ring uses key" do
    area = life_areas(:one_self)
    assert_equal LifeArea.world_ring_for(area.key), area.world_ring
  end

  test "key_for_ring maps creatable rings and hides infinity" do
    assert_equal "self", LifeArea.key_for_ring("me")
    assert_equal "relationships", LifeArea.key_for_ring("family_love")
    assert_equal "career", LifeArea.key_for_ring("friends_work")
    assert_equal "community", LifeArea.key_for_ring("people")
    assert_equal "nature", LifeArea.key_for_ring("animals_nature")
    assert_equal "money", LifeArea.key_for_ring("things_money")
    assert_equal "purpose", LifeArea.key_for_ring("spirit")
    assert_nil LifeArea.key_for_ring("infinity")
    assert_nil LifeArea.key_for_ring("spaceships")
    assert_nil LifeArea.key_for_ring(nil)
    assert_equal 7, LifeArea.creatable_world_rings.size
    refute_includes LifeArea.creatable_world_rings, "infinity"
  end
end
