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
end
