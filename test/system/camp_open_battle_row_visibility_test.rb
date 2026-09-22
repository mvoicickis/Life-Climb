# frozen_string_literal: true

require "application_system_test_case"

class CampOpenBattleRowVisibilityTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(360, 800)
    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox", mountain_trail_tour_ack: 7)
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Day two camp", position: 0,
      trail_x: 0.5, trail_y: 0.62, color_key: "teal"
    )
    @long_title = "Handle Day 2 problem with a very long name that must wrap on a narrow phone"
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: @long_title, scheduled_on: Date.current, position: 0
    )
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Short B", scheduled_on: Date.current, position: 1
    )
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Short C", scheduled_on: Date.current, position: 2
    )
  end

  test "open camp battle rows show tick and title inside the row at 360px" do
    sign_in_and_open_camp!

    rows = page.evaluate_script(row_visibility_script(@project.id))
    assert_equal 3, rows.size, "expected three open battle rows"

    rows.each_with_index do |row, index|
      assert row["tickInside"], "row #{index}: tick should sit inside the row box"
      assert row["nameInside"], "row #{index}: title should sit inside the row box"
      assert row["nameVisible"], "row #{index}: title should be visible"
      assert row["nameWidth"].to_f > 8, "row #{index}: title should have readable width"
    end

    long_row = rows.find { |r| r["title"]&.include?("Handle Day 2") }
    assert long_row, "expected long-title battle in the list"
    assert long_row["nameWidth"].to_f < 280, "long title should wrap within the row, not overflow invisibly"
  end

  test "finish and completed camp cards stay vertically centered in the scroll area" do
    sign_in_and_open_camp!

    @project.children.order(:position).each do |battle|
      within("#trail-battle-#{battle.id}", wait: 5) { find(".lp-trail-battles__tick").click }
      assert_selector "#trail-battle-#{battle.id}.is-won", wait: 5
    end

    assert_selector "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__cta", wait: 5
    assert page.evaluate_script(idle_scroll_centered_script(@project.id)),
           "finish prompt scroll area should stay centered (is-idle)"

    click_button I18n.t("strategy.rpg.trail.finish_camp_card.cta")
    assert_selector "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__undo", wait: 5
    assert_selector "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__completed", wait: 8
    assert page.evaluate_script(idle_scroll_centered_script(@project.id)),
           "completed card scroll area should stay centered (is-idle)"
  end

  private

  def sign_in_and_open_camp!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#mountain-trail", wait: 5
    open_trail_camp_sheet!(@project)
    assert_selector "#trail-battles-list-#{@project.id} .lp-trail-battles__row.is-open", minimum: 3, wait: 5
  end

  def row_visibility_script(project_id)
    <<~JS
      (function() {
        function inside(parent, child) {
          const p = parent.getBoundingClientRect();
          const c = child.getBoundingClientRect();
          if (c.width < 2 || c.height < 2) return false;
          return c.left >= p.left - 2 &&
                 c.top >= p.top - 2 &&
                 c.right <= p.right + 2 &&
                 c.bottom <= p.bottom + 2;
        }
        function isVisible(el) {
          if (!el) return false;
          const s = getComputedStyle(el);
          if (s.visibility === "hidden" || s.display === "none") return false;
          if (parseFloat(s.opacity) < 0.2) return false;
          const r = el.getBoundingClientRect();
          return r.width > 2 && r.height > 2;
        }
        const list = document.querySelector("#trail-battles-list-#{project_id}");
        if (!list) return [];
        return [...list.querySelectorAll(".lp-trail-battles__row.is-open")].map((row) => {
          const tick = row.querySelector(".lp-trail-battles__tick, .lp-trail-battles__tick-form");
          const name = row.querySelector(".lp-trail-battles__name");
          return {
            title: name ? name.textContent.trim() : "",
            tickInside: tick ? inside(row, tick) : false,
            nameInside: name ? inside(row, name) : false,
            nameVisible: isVisible(name),
            nameWidth: name ? name.getBoundingClientRect().width : 0
          };
        });
      })();
    JS
  end

  def idle_scroll_centered_script(project_id)
    <<~JS
      (function() {
        const scroll = document.querySelector("#trail-battles-#{project_id} .lp-trail-battles__scroll");
        if (!scroll || !scroll.classList.contains("is-idle")) return false;
        const s = getComputedStyle(scroll);
        return s.display === "flex" && s.justifyContent === "center";
      })();
    JS
  end
end
