# frozen_string_literal: true

require "test_helper"

class V2OnboardingTrailMarkersTest < ActionDispatch::IntegrationTest
  include MountainTrailHelper

  setup do
    @password = "password12345"
  end

  test "intro camps sit on art surface at builtin slot positions" do
    user = create_user!("intro-markers")
    sign_in_as user

    get v2_onboarding_path(step: "intro_big_goals")
    assert_response :success

    assert_select ".lp-ob-intro__art .lp-ob-art-surface.lp-ob-art-surface--intro" do
      assert_select ".lp-ob-intro__camp", count: 3
      mountain_trail_intro_camp_positions.each do |pos|
        assert_select ".lp-ob-intro__camp[style*='--lp-trail-x: #{pos[:x]}'][style*='--lp-trail-y: #{pos[:y]}']", count: 1
      end
    end
  end

  test "climb camps and peak sit on art surface at builtin positions" do
    user = create_user!("climb-markers")
    Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Learn baking",
      camp_titles: [ "Basics", "Bread", "Pastry" ],
      complete_onboarding: false,
      first_camp_reveal_status: "done"
    )
    sign_in_as user

    get v2_onboarding_path(step: "climb")
    assert_response :success

    assert_select ".lp-ob-climb__bg .lp-ob-art-surface.lp-ob-art-surface--climb" do
      assert_select ".lp-ob-climb__summit[style*='--lp-trail-x: #{MountainTrailHelper::PEAK_X}'][style*='--lp-trail-y: #{MountainTrailHelper::PEAK_Y}']", count: 1
      assert_select ".lp-ob-climb__camp", count: 3
      mountain_trail_intro_camp_positions.each do |pos|
        assert_select ".lp-ob-climb__camp[style*='--lp-trail-x: #{pos[:x]}'][style*='--lp-trail-y: #{pos[:y]}']", count: 1
      end
    end
  end

  test "celebrate confetti spans have distinct left values" do
    user = create_user!("celebrate-confetti")
    Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Learn baking",
      camp_titles: [ "Basics" ],
      complete_onboarding: false,
      first_camp_reveal_status: "done"
    )
    journey = user.primary_focused_journey
    journey.mark_onboarding_v3_climb_done!
    Onboarding::PlantBattles.call(
      user: user,
      journey: journey,
      battle_titles: [ "Practice scales" ]
    )
    sign_in_as user

    get v2_onboarding_path(step: "celebrate")
    assert_response :success

    lefts = response.body.scan(/lp-ob-celebrate__confetti[\s\S]*?<\/div>/).first
      .to_s
      .scan(/left:\s*([\d.]+)%/)
      .flatten
      .map(&:to_f)
    assert_equal 8, lefts.size
    assert_equal lefts, lefts.uniq
    assert_operator lefts.min, :>=, 5
    assert_operator lefts.max, :<=, 95
  end

  private

  def create_user!(label)
    User.create!(
      name: "Alex",
      email_address: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: @password,
      password_confirmation: @password,
      character: "fox"
    )
  end
end
