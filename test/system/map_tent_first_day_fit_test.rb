# frozen_string_literal: true

require "application_system_test_case"

class MapTentFirstDayFitTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      name: "Map Fit",
      email_address: "map-fit-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Health journey",
      camp_titles: [
        "Weight myself every morning",
        "Save for gym gear",
        "Run a 5K"
      ]
    )
    @journey = @result.journey
    @goal = @result.goal
    @plan = @result.plan
    @first_camp = @result.projects.first
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey.clear_first_camp_reveal!
    page.driver.browser.manage.window.resize_to(360, 800)
  end

  test "first day bottom camp and three tent sizes fit photo at 360px" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#trail-map-camps .lp-trail-camp.is-current", wait: 10

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const photo = document.querySelector(".lp-trail__photo--day, .lp-trail__photo");
        if (!photo) return { ok: false, reason: "no photo" };
        const pr = photo.getBoundingClientRect();
        const inside = (el) => {
          if (!el) return true;
          const r = el.getBoundingClientRect();
          return r.left >= pr.left - 0.5 && r.right <= pr.right + 0.5 &&
                 r.top >= pr.top - 0.5 && r.bottom <= pr.bottom + 0.5;
        };
        const camp = document.querySelector("#trail-map-camps .lp-trail-camp.is-current");
        if (!camp) return { ok: false, reason: "no current camp" };
        const ring = camp.querySelector(".lp-trail-camp__ring");
        const fire = camp.querySelector(".lp-trail-camp__fire");
        const caption = camp.querySelector(".lp-trail-camp__caption");
        const camps = Array.from(document.querySelectorAll("#trail-map-camps .lp-trail-camp"));
        const tentWidths = camps.map((c) => {
          const tent = c.querySelector(".lp-trail-camp__tent");
          return tent ? tent.getBoundingClientRect().width : 0;
        });
        const sizeOk = tentWidths.length >= 3 &&
          tentWidths[0] > tentWidths[1] && tentWidths[1] > tentWidths[2];
        return {
          ok: inside(camp) && inside(ring) && inside(fire) && inside(caption) && sizeOk,
          insideCamp: inside(camp),
          insideRing: inside(ring),
          insideFire: inside(fire),
          insideCaption: inside(caption),
          tentWidths,
          sizeOk
        };
      })()
    JS

    assert metrics["insideCamp"], metrics.inspect
    assert metrics["insideRing"], metrics.inspect
    assert metrics["insideFire"], metrics.inspect
    assert metrics["insideCaption"], metrics.inspect
    assert metrics["sizeOk"], metrics.inspect
    assert metrics["ok"], metrics.inspect
  end
end
