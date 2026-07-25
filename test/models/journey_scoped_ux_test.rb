require "test_helper"

class JourneyScopedUxTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
    LifeAreas::Select.call(user: @user, keys: %w[career purpose])
    areas = @user.life_areas.v2_selected.index_by(&:key)
    @career = areas.fetch("career")
    @purpose = areas.fetch("purpose")

    @j1 = Journeys::Create.call(
      user: @user,
      life_area: @career,
      title: "Career path",
      ideal_scene: "Senior Rails engineer",
      current_reality: "Learning Rails",
      closer_percent: 40
    )
    @j2 = Journeys::Create.call(
      user: @user,
      life_area: @purpose,
      title: "Purpose path",
      ideal_scene: "Clear meaning",
      current_reality: "Searching",
      closer_percent: 10
    )
    Focus::SetJourneys.call(user: @user, journey_ids: [ @j1.id, @j2.id ])
  end

  test "area vitality and closer come from representative journey gap" do
    @career.reload
    assert_in_delta 60.0, @career.journey_gap_percent, 0.01
    assert_equal 40, @career.journey_closer_percent
    assert_equal 2, @career.vitality
  end

  test "attention journey is the focused journey with the worst gap" do
    attention = @user.attention_journey
    assert_equal @j2.id, attention.id
  end

  test "closing gap raises vitality toward blooming" do
    @j1.update!(gap_percent: 15)
    assert_equal 5, @career.reload.vitality
  end
end
