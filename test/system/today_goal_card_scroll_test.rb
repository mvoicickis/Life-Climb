# frozen_string_literal: true

require "application_system_test_case"

class TodayGoalCardScrollSystemTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(360, 640)
    @journey = seed_climb!(@user, today_mission: "Battle one")
    dismiss_onboarding_missions!(@user)
    @camp = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert @camp.present?

    clear_camp_battles!
    add_camp_battle!("Battle one", position: 0, on: Date.current)
    add_camp_battle!("Battle two", position: 1, on: Date.current)
    add_camp_battle!("Battle three", position: 2, on: Date.current)
  end

  test "short Today scroll does not flip goal card collapse more than once" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    assert_selector ".lp-today-group-card--goal[data-controller~='today-goal-card']"

    page.execute_script(<<~JS)
      (() => {
        const card = document.querySelector(".lp-today-group-card--goal");
        const pad = document.querySelector(".lp-today-scroll__pad");
        window.__lpGoalFlips = 0;
        window.__lpGoalLastCollapsed = card.classList.contains("is-collapsed");
        if (window.__lpGoalObs) window.__lpGoalObs.disconnect();
        window.__lpGoalObs = new MutationObserver(() => {
          const now = card.classList.contains("is-collapsed");
          if (now !== window.__lpGoalLastCollapsed) {
            window.__lpGoalFlips += 1;
            window.__lpGoalLastCollapsed = now;
          }
        });
        window.__lpGoalObs.observe(card, { attributes: true, attributeFilter: ["class"] });
        window.__lpGoalPad = pad;
      })()
    JS

    20.times do |i|
      y = (i * 6) % 90
      page.execute_script("window.__lpGoalPad.scrollTop = #{y}")
      sleep 0.03
    end
    sleep 0.35

    flips = page.evaluate_script("window.__lpGoalFlips")
    assert_operator flips.to_i, :<=, 1,
                    "expected at most one is-collapsed flip on a short Today, got #{flips}"
  ensure
    page.execute_script("window.__lpGoalObs && window.__lpGoalObs.disconnect()") rescue nil
  end

  private

  def clear_camp_battles!
    battle_ids = @camp.children.where(horizon: "day").pluck(:id)
    @user.daily_todos.where(strategy_goal_id: battle_ids).delete_all if battle_ids.any?
    @camp.children.where(horizon: "day").delete_all
  end

  def add_camp_battle!(title, position:, on: nil)
    battle = @camp.children.create!(
      user: @user,
      life_area: @journey.life_area,
      life_journey: @journey,
      horizon: "day",
      title: title,
      scheduled_on: on || Date.current + position.days,
      position: position
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
    battle
  end
end
