# frozen_string_literal: true

require "application_system_test_case"

class CampArrangeAddTest < ApplicationSystemTestCase
  def setup_user_with_camps!(email:, camps:)
    user = User.create!(
      name: "Alex",
      email_address: email,
      password: "password12345",
      planning_version: 2
    )
    allow_extra_climbs!(user)
    Onboarding::Bootstrap.call(user: user, goal_title: "Climb goal", camp_titles: camps)
    user.primary_focused_journey.clear_first_camp_reveal!
    user.update!(
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ],
      character: "fox",
      mountain_trail_tour_ack: 7
    )
    user
  end

  def sign_in_and_visit_mountain!(user)
    journey = user.primary_focused_journey
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    goal = plan.root_goal

    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8
    visit life_journey_path(journey, goal_id: goal.id, plan_id: plan.id)
    assert_selector "#mountain-trail", wait: 10
  end

  def open_arrange_overlay!
    plaque = find(".lp-trail__goal-plaque", visible: :all)
    page.execute_script("arguments[0].click()", plaque.native)
    assert_selector ".lp-trail__goal-menu:not([hidden])", wait: 3
    click_button "Change camp order"
    assert_selector "#trail-arrange-camps:not([hidden])", wait: 5
    assert page.evaluate_script("document.body.classList.contains('is-arrange-open')")
  end

  def begin_add_camp!
    click_button "+ Add a camp"
    assert_selector ".lp-trail-arrange-add.is-editing", wait: 3
    find(".lp-trail-arrange-add__input")
  end

  setup do
    page.driver.browser.manage.window.resize_to(360, 800)
  end

  test "enter saves camps and keeps the same input focused" do
    user = setup_user_with_camps!(
      email: "camp-add-focus@example.com",
      camps: [ "Alpha", "Beta", "Gamma" ]
    )
    sign_in_and_visit_mountain!(user)
    open_arrange_overlay!
    begin_add_camp!

    page.execute_script("window.__addInputNode = document.querySelector('.lp-trail-arrange-add__input')")

    input = find(".lp-trail-arrange-add__input")
    input.set("Delta camp")
    input.send_keys(:enter)
    assert_selector ".lp-pointer-reorder__row", text: "Delta camp", wait: 5
    assert page.evaluate_script("document.querySelector('.lp-trail-arrange-add__input') === window.__addInputNode")
    assert page.evaluate_script("document.querySelector('.lp-trail-arrange-add__input') === document.activeElement")

    input.set("Epsilon camp")
    input.send_keys(:enter)
    assert_selector ".lp-pointer-reorder__row", text: "Epsilon camp", wait: 5
    assert page.evaluate_script("document.querySelector('.lp-trail-arrange-add__input') === window.__addInputNode")
  end

  test "escape cancels add without creating a camp" do
    user = setup_user_with_camps!(
      email: "camp-add-esc@example.com",
      camps: [ "One", "Two" ]
    )
    plan = user.strategy_goals.for_kind("plan").not_holding.first
    before = plan.children.for_kind("project").count

    sign_in_and_visit_mountain!(user)
    open_arrange_overlay!
    begin_add_camp!

    input = find(".lp-trail-arrange-add__input")
    input.set("Ghost camp")
    input.send_keys(:escape)

    assert_no_selector ".lp-trail-arrange-add.is-editing"
    assert_equal before, plan.reload.children.for_kind("project").count
    assert_no_selector ".lp-pointer-reorder__row", text: "Ghost camp"
  end

  test "blur after enter does not create a duplicate camp" do
    user = setup_user_with_camps!(
      email: "camp-add-blur@example.com",
      camps: [ "One", "Two" ]
    )
    plan = user.strategy_goals.for_kind("plan").not_holding.first

    sign_in_and_visit_mountain!(user)
    open_arrange_overlay!
    begin_add_camp!

    input = find(".lp-trail-arrange-add__input")
    input.set("Solo camp")
    input.send_keys(:enter)
    assert_selector ".lp-pointer-reorder__row", text: "Solo camp", wait: 5
    page.execute_script("document.querySelector('.lp-trail-arrange-add__input').blur()")

    assert_equal 1, plan.reload.children.for_kind("project").where(title: "Solo camp").count
  end

  test "drag after add saves order once" do
    user = setup_user_with_camps!(
      email: "camp-add-drag@example.com",
      camps: [ "Base", "Ridge" ]
    )
    sign_in_and_visit_mountain!(user)
    open_arrange_overlay!
    begin_add_camp!

    input = find(".lp-trail-arrange-add__input")
    input.set("New peak")
    input.send_keys(:enter)
    assert_selector ".lp-pointer-reorder__row", text: "New peak", wait: 5

    page.execute_script(<<~JS)
      window.__arrangePatches = 0;
      const orig = window.fetch;
      window.fetch = function(url, opts) {
        const method = (opts && opts.method) || "GET";
        if (method.toUpperCase() === "PATCH" && String(url).includes("camp_arrangement")) {
          window.__arrangePatches += 1;
        }
        return orig.apply(this, arguments);
      };
    JS

    page.execute_script(<<~JS)
      const row = [...document.querySelectorAll(".lp-pointer-reorder__row")].find((el) =>
        el.querySelector(".lp-trail-arrange-row__label-btn")?.textContent?.trim() === "New peak"
      );
      if (!row) throw new Error("row missing");
      const targetList = document.querySelector(".lp-trail-arrange-group [data-arrange-list]");
      if (!targetList) throw new Error("target list missing");
      const targetRect = targetList.getBoundingClientRect();
      const handle = row.querySelector(".lp-pointer-reorder__handle");
      const rect = handle.getBoundingClientRect();
      const pointerId = 42;
      const base = {
        bubbles: true,
        cancelable: true,
        pointerId,
        pointerType: "mouse",
        isPrimary: true,
        button: 0,
        buttons: 1
      };
      handle.dispatchEvent(new PointerEvent("pointerdown", { ...base, clientX: rect.left + 6, clientY: rect.top + 6 }));
      const targetY = targetRect.top + targetRect.height / 2;
      for (let y = rect.top; y >= targetY; y -= 24) {
        handle.dispatchEvent(new PointerEvent("pointermove", { ...base, clientX: targetRect.left + 20, clientY: y }));
      }
      handle.dispatchEvent(new PointerEvent("pointermove", { ...base, clientX: targetRect.left + 20, clientY: targetY }));
      handle.dispatchEvent(new PointerEvent("pointerup", { ...base, clientX: targetRect.left + 20, clientY: targetY, buttons: 0 }));
    JS

    assert_selector ".lp-trail-arrange__toast.is-visible", text: /Order saved/i, wait: 5
    assert page.evaluate_script("window.__arrangePatches === 1"), "expected one reorder save"
  end
end
