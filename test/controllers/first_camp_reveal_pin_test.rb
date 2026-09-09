# frozen_string_literal: true

require "test_helper"

class FirstCampRevealPinTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-camp-pin-ui-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    sign_in_as @user
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship it",
      camp_titles: [ "First camp", "Second camp" ]
    )
    @journey = @result.journey
    @first_camp = @result.projects.first
    @second_camp = @result.projects.second
  end

  test "mountain shows setup only on pinned camp" do
    get life_journey_path(@journey)

    assert_response :success
    assert_select ".lp-trail.is-first-camp-reveal"
    assert_select "#trail-sheet-camp-#{@first_camp.id} .lp-first-camp-setup"
    assert_select "#trail-sheet-camp-#{@second_camp.id} .lp-first-camp-setup", count: 0
    assert_select "#trail-sheet-camp-#{@second_camp.id} .lp-trail-battles"
  end

  test "setup sheet shows camp title submit button and enter hint" do
    get life_journey_path(@journey)

    assert_response :success
    assert_select "#trail-sheet-title", text: @first_camp.title, count: 1
    assert_select ".lp-first-camp-setup__title", count: 0
    assert_select ".lp-trail.is-first-camp-reveal .lp-trail-sheet__menu-btn", count: 0
    assert_select ".lp-trail.is-first-camp-reveal .lp-trail-sheet__close", count: 0
    assert_select "#trail-sheet-camp-#{@first_camp.id} input[type=submit][value=?]",
                  I18n.t("strategy.rpg.trail.first_camp_reveal.submit")
    assert_select "#trail-sheet-camp-#{@first_camp.id} .lp-first-camp-setup__hint",
                  text: I18n.t("strategy.rpg.trail.first_camp_reveal.dock_note")
    assert_select "#trail-sheet-camp-#{@first_camp.id} [data-action*='first-camp-battle#titleKeydown']"
    assert_select "#trail-sheet-camp-#{@first_camp.id} input[placeholder=?]",
                  I18n.t("strategy.rpg.trail.first_camp_reveal.title_placeholder")
  end

  test "dismissed reveal restores camp sheet header actions" do
    patch life_journey_first_camp_reveal_path(@journey), as: :turbo_stream

    get life_journey_path(@journey)

    assert_response :success
    assert_select ".lp-trail.is-first-camp-reveal", count: 0
    assert_select "#trail-sheet-menu-#{@first_camp.id} .lp-trail-sheet__menu-btn"
    assert_select ".lp-trail-sheet__close"
  end

  test "completing pinned camp does not show setup on another camp" do
    @first_camp.complete!

    get life_journey_path(@journey)

    assert_response :success
    assert_select ".lp-trail.is-first-camp-reveal", count: 0
    assert_select ".lp-first-camp-setup", count: 0
    refute @journey.reload.first_camp_reveal_pending?
  end

  test "pending reveal without stored camp id shows no setup sheet" do
    @journey.update_columns(
      setup_flags: { Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG => "pending" },
      updated_at: Time.current
    )

    get life_journey_path(@journey)

    assert_response :success
    assert_select ".lp-first-camp-setup", count: 0
    assert_equal "done", @journey.reload.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_REVEAL_FLAG)
  end

  test "dismiss replaces pinned camp panel" do
    patch life_journey_first_camp_reveal_path(@journey), as: :turbo_stream

    assert_response :success
    assert_match "trail-sheet-camp-#{@first_camp.id}", response.body
    assert_match "lp-trail-battles", response.body
    refute_match "trail-sheet-camp-#{@second_camp.id}", response.body
  end

  test "save replaces pinned camp panel" do
    post life_journey_first_camp_battles_path(@journey),
         params: { title: "Write the README", repeat: "none" },
         as: :turbo_stream

    assert_response :success
    assert_match "trail-sheet-camp-#{@first_camp.id}", response.body
    assert_match "lp-trail-battles", response.body
    refute @journey.reload.first_camp_reveal_pending?
  end
end
