# frozen_string_literal: true

require "test_helper"

class FirstCampWinPromptTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-camp-win-#{SecureRandom.hex(4)}@example.com",
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
    @project = @result.projects.first
    @seed = @result.first_battle
  end

  def save_first_battle!(title: "Call my mum")
    post life_journey_first_camp_battles_path(@journey),
         params: { title: title, repeat: "none" },
         as: :turbo_stream
    assert_response :success
    @project.reload.children.for_kind("day").sole
  end

  test "save shows normal row with hint and add battle" do
    battle = save_first_battle!

    assert @journey.reload.first_camp_win_nudge_pending?
    refute @journey.first_camp_reveal_pending?
    refute_match "lp-first-camp-win-prompt", response.body
    refute_match "Do it later", response.body
    refute_equal @seed.id, @project.reload.children.for_kind("day").sole.id

    assert_select "#trail-battles-#{@project.id}"
    assert_select ".lp-trail-battles__kebab-btn"
    assert_select "#trail-battle-#{battle.id} .lp-trail-battles__first-camp-hint",
                  text: I18n.t("strategy.rpg.trail.first_camp_reveal.tap_when_done")
    assert_select ".lp-trail-battles__composer-trigger", text: /#{Regexp.escape(I18n.t("strategy.rpg.trail.add_battle"))}/
  end

  test "reload with nudge pending shows hint not setup form" do
    battle = save_first_battle!

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-first-camp-setup", count: 0
    assert_select "#trail-battle-#{battle.id} .lp-trail-battles__first-camp-hint"
    assert_select ".lp-trail-battles__composer-trigger"
  end

  test "camp sheet win shows first battle won finish card and won strip" do
    battle = save_first_battle!

    post battle_win_path(battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :success

    refute @journey.reload.first_camp_win_nudge_pending?
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.first_win_title"), response.body
    refute_match I18n.t("strategy.rpg.trail.finish_camp_card.title"), response.body
    assert_equal 1, @user.user_events.named("first_battle_won").count
    assert_select "#trail-battles-won-strip-#{@project.id}",
                  text: /#{Regexp.escape(I18n.t("strategy.rpg.trail.won_battles_strip"))} \(1\)/
    refute_match "lp-trail-battles__first-camp-hint", response.body
  end

  test "win from Today clears nudge and camp sheet shows won row" do
    battle = save_first_battle!
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)

    post complete_daily_todo_path(todo), as: :turbo_stream
    assert_response :success
    refute @journey.reload.first_camp_win_nudge_pending?

    get life_journey_path(@journey, focus_id: @project.id)
    assert_response :success
    assert_select ".lp-trail-battles__first-camp-hint", count: 0
    assert_select ".lp-trail-battles__row.is-won"
  end

  test "dismiss nudge route is removed" do
    save_first_battle!

    patch "/life_journeys/#{@journey.id}/first_camp_win_nudge", as: :turbo_stream
    assert_response :not_found
  end
end
