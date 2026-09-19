# frozen_string_literal: true

require "application_system_test_case"

class TrailMapCaptionWidthTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(360, 640)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship the MVP",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Design battle card",
      closer_percent: 40,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    @camp_titles = [
      "Authentication flow",
      "Daily battles hub",
      "Dashboard widgets",
      "Notification center"
    ]
    @camp_titles.each_with_index do |title, i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: title, position: i
      )
    end
    @current = @plan.children.for_kind("project").order(:position).first
    @leaf = practice_leaf_for!(@current)
    host = Strategy::EnsureFolderQuest.call(folder: @leaf)
    host.practice_tasks.create!(user: @user, title: "Wire login", position: 0)
  end

  test "three camp map captions stay wide and wrap on word boundaries at 360px" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#mountain-trail.lp-trail.is-v4", visible: :all, wait: 5
    assert_selector "#trail-map-camps .lp-trail-camp", count: 3, visible: :all, wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        return Array.from(document.querySelectorAll("#trail-map-camps .lp-trail-camp__caption")).map((caption) => {
          const title = caption.querySelector(".lp-trail-camp__title");
          const r = caption.getBoundingClientRect();
          const text = title ? (title.textContent || "").trim() : "";
          const midWordClip = /\\S…/.test(text) || /\\w\\.\\.\\.$/.test(text);
          return { width: r.width, text, midWordClip };
        });
      })()
    JS

    assert_equal 3, metrics.length
    metrics.each do |row|
      assert_operator row["width"], :>=, 80,
                     "caption too narrow (#{row['width']}px) for “#{row['text']}”"
      refute row["midWordClip"], "title looks mid-word clipped: #{row['text'].inspect}"
    end
  end
end
