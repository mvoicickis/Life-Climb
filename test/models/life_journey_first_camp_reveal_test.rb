# frozen_string_literal: true

require "test_helper"

class LifeJourneyFirstCampRevealTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-camp-pin-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship it",
      camp_titles: [ "First camp", "Second camp" ]
    )
    @journey = @result.journey
    @first_camp = @result.projects.first
    @second_camp = @result.projects.second
  end

  test "bootstrap pins first camp id in setup flags" do
    assert_equal @first_camp.id, @journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_ID_FLAG).to_i
    assert @journey.first_camp_reveal_pending?
    assert_equal @first_camp.id, @journey.first_camp_reveal_camp_id
    assert_equal @first_camp, @journey.first_camp_reveal_project
  end

  test "pending flag without stored camp id clears reveal" do
    @journey.update_columns(
      setup_flags: {
        Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG => "pending"
      },
      updated_at: Time.current
    )

    refute @journey.reload.first_camp_reveal_pending?
    assert_equal "done", @journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)
    assert_nil @journey.first_camp_reveal_camp_id
  end

  test "completing pinned camp clears reveal instead of moving it" do
    @first_camp.complete!

    refute @journey.reload.first_camp_reveal_pending?
    assert_nil @journey.first_camp_reveal_camp_id
    assert_nil @journey.first_camp_reveal_project
  end

  test "missing pinned camp clears reveal" do
    flags = @journey.setup_flags.stringify_keys.merge(
      Onboarding::Bootstrap::FIRST_CAMP_ID_FLAG => 9_999_999
    )
    @journey.update_columns(setup_flags: flags, updated_at: Time.current)

    refute @journey.reload.first_camp_reveal_pending?
    assert_equal "done", @journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)
  end
end
