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

  test "save shows win prompt with coach and circle" do
    save_first_battle!

    assert @journey.reload.first_camp_win_nudge_pending?
    refute @journey.first_camp_reveal_pending?
    assert_match "lp-first-camp-win-prompt", response.body
    assert_includes response.body, "lp-first-camp-win-prompt__coach"
    assert_match I18n.t("strategy.rpg.trail.first_camp_reveal.do_it_later"), response.body
    refute_equal @seed.id, @project.reload.children.for_kind("day").sole.id
  end

  test "reload with nudge pending shows win prompt not setup form" do
    save_first_battle!

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-first-camp-win-prompt"
    assert_select ".lp-first-camp-setup", count: 0
  end

  test "camp sheet win shows first battle won finish card" do
    battle = save_first_battle!

    post battle_win_path(battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :success

    refute @journey.reload.first_camp_win_nudge_pending?
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.first_win_title"), response.body
    refute_match I18n.t("strategy.rpg.trail.finish_camp_card.title"), response.body
    assert_equal 1, @user.user_events.named("first_battle_won").count
  end

  test "win from Today clears nudge and camp sheet shows won row" do
    battle = save_first_battle!
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)

    post complete_daily_todo_path(todo), as: :turbo_stream
    assert_response :success
    refute @journey.reload.first_camp_win_nudge_pending?

    get life_journey_path(@journey, focus_id: @project.id)
    assert_response :success
    assert_select ".lp-first-camp-win-prompt", count: 0
    assert_select ".lp-trail-battles__row.is-won"
  end

  test "do it later clears nudge and shows normal camp battles" do
    save_first_battle!
    assert @journey.reload.first_camp_win_nudge_pending?

    patch life_journey_first_camp_win_nudge_path(@journey), as: :turbo_stream
    assert_response :success
    refute @journey.reload.first_camp_win_nudge_pending?
    assert_match "lp-trail-battles", response.body
    refute_match "lp-first-camp-win-prompt", response.body
    assert @user.daily_todos.for_day.exists?(strategy_goal_id: @project.children.for_kind("day").sole.id)
  end
end
