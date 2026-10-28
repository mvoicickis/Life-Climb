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

  test "first camp win includes camp push offer host when eligible" do
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_last_shown_on: nil,
      push_offer_show_days: 0
    )
    goal = @result.goal || @project.root_goal
    tricky = 'Ship <b>it</b> & "go"'
    goal.update!(title: tricky)
    Goals::Current.clear_cache!(user: @user)
    battle = save_first_battle!

    post battle_win_path(battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :success

    host = css_select("#mountain-push-offer-host").first
    assert host
    assert_equal "true", host["data-push-offer-compact-value"]
    assert_equal "false", host["data-push-offer-show-not-now-value"]
    assert_equal "true", host["data-push-offer-mark-shown-on-display-value"]
    assert_equal "false", host["data-push-offer-count-show-day-value"]
    assert_equal "true", host["data-push-offer-camp-sheet-value"]
    assert_equal "camp_sheet", host["data-push-offer-source-value"]
    assert_equal tricky, host["data-push-offer-goal-title-value"]
    assert_equal I18n.t("dash.push_offer.mountain_label"), host["data-push-offer-mountain-label-value"]
    assert_equal I18n.t("dash.push_offer.mountain_line"), host["data-push-offer-mountain-line-value"]
    assert_equal I18n.t("dash.push_offer.mountain_yes"), host["data-push-offer-mountain-yes-value"]
    assert_equal I18n.t("dash.push_offer.mountain_done"), host["data-push-offer-mountain-done-value"]
    assert_equal I18n.t("dash.push_offer.ios_steps"), host["data-push-offer-ios-steps-value"]
    assert_equal I18n.t("dash.push_offer.camp_ios_label"), host["data-push-offer-camp-ios-label-value"]
    assert_equal I18n.t("dash.push_offer.camp_ios_title"), host["data-push-offer-camp-ios-title-value"]
    assert_equal I18n.t("dash.push_offer.camp_ios_steps"), host["data-push-offer-camp-ios-steps-value"]
    assert_equal I18n.t("dash.push_offer.camp_inapp_label"), host["data-push-offer-camp-inapp-label-value"]
    assert_equal I18n.t("dash.push_offer.camp_inapp_title"), host["data-push-offer-camp-inapp-title-value"]
    assert_equal I18n.t("dash.push_offer.camp_inapp_steps"), host["data-push-offer-camp-inapp-steps-value"]
    assert_select "#mountain-push-offer-host[hidden]"
    assert_select ".lp-trail-camp-finish__card #mountain-push-offer-host", count: 0
    assert_select ".lp-trail-camp-finish > #mountain-push-offer-host"
    assert_select ".lp-trail-camp-finish:not(.is-push-offer-open) .lp-trail-camp-finish__cta"
    assert_select ".lp-trail-camp-finish__reminder-divider", count: 0
    assert_select ".lp-push-offer__not-now", count: 0
    refute_includes response.body, "<b>it</b>"
    assert_equal 0, @user.reload.push_offer_show_days
  end

  test "first camp win omits push offer when permission denied" do
    @user.update!(push_offer_permission_denied_at: Time.current)
    battle = save_first_battle!

    post battle_win_path(battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :success

    assert_select "#mountain-push-offer-host", count: 0
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
