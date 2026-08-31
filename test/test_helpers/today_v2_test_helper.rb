# frozen_string_literal: true

# Shared assertions for Today V2 battlefield UI (when @show_plan_route is false).
module TodayV2TestHelper
  def assert_today_v2_all_clear_shell!
    if integration_test?
      assert_select ".lp-dash.is-today-v2", count: 1
      assert_select "#today-end-of-day", count: 1
      assert_select ".lp-today-v2-eod-win__title", text: "You cleared the field"
    else
      assert_selector ".lp-dash.is-today-v2", count: 1
      assert_text "You cleared the field", wait: 5
      assert_selector "#today-end-of-day", visible: :all
    end
  end

  def assert_today_v2_shell!
    if integration_test?
      assert_select ".lp-dash.is-today-v2", count: 1
      assert_select ".lp-today-v2-header", count: 1
      assert_select ".lp-today-v2-field", count: 1
      assert_select ".lp-dash-nav.is-today-v2", count: 1
    else
      assert_selector ".lp-dash.is-today-v2", count: 1
      assert_selector ".lp-today-v2-header", count: 1
      assert_selector ".lp-today-v2-field", count: 1
      assert_selector ".lp-dash-nav.is-today-v2", count: 1
    end
  end

  def assert_no_legacy_today_shell!
    if integration_test?
      assert_select ".lp-dash-hero", count: 0
      assert_select ".lp-dash-timeline", count: 0
      assert_select ".lp-dash-daystrip", count: 0
      assert_select ".lp-dash-done-fold", count: 0
    else
      assert_no_selector ".lp-dash-hero"
      assert_no_selector ".lp-dash-timeline"
      assert_no_selector ".lp-dash-daystrip"
      assert_no_selector ".lp-dash-done-fold"
    end
  end

  def assert_battle_row!(title:, camp: nil, todo: nil)
    if integration_test?
      assert_select ".lp-today-v2-row__title", text: title
      assert_select ".lp-today-v2-row__camp", text: /#{Regexp.escape(camp)}/ if camp
      assert_select ".lp-today-v2-row[data-todo-id=?]", todo.id.to_s if todo
    else
      assert_selector ".lp-today-v2-row__title", text: title
      assert_selector ".lp-today-v2-row__camp", text: /#{Regexp.escape(camp)}/ if camp
      assert_selector ".lp-today-v2-row[data-todo-id='#{todo.id}']" if todo
    end
  end

  def assert_battle_row_absent!(title:)
    if integration_test?
      assert_select ".lp-today-v2-row__title", text: title, count: 0
    else
      assert_no_selector ".lp-today-v2-row__title", text: title
    end
  end

  def dismiss_onboarding_missions!(user)
    user.missions.for_day(Date.current).primary.incomplete.find_each do |mission|
      Missions::Complete.call(user: user, mission: mission)
    end
  end

  # System tests — complete a practice objective when Today V2 has no quest sheet UI.
  def patch_practice_task!(task, completed: "1", amount: nil)
    params = { completed: completed }
    params[:amount] = amount if amount
    page.execute_script(<<~JS, practice_task_path(task), params)
      (async () => {
        const url = arguments[0];
        const params = arguments[1];
        const csrf = document.querySelector("meta[name='csrf-token']")?.content;
        await fetch(url, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrf,
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "text/vnd.turbo-stream.html, text/html"
          },
          body: new URLSearchParams(params).toString(),
          credentials: "same-origin"
        });
      })();
    JS
    sleep 0.4
  end

  def click_battle_row_check!(todo: nil, label: nil)
    selector =
      if todo
        ".lp-today-v2-row[data-todo-id='#{todo.id}'] .lp-today-v2-row__check"
      else
        "button.lp-today-v2-row__check[aria-label*='#{label}']"
      end
    find(selector).click
  end

  private

  def integration_test?
    !respond_to?(:assert_selector)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include TodayV2TestHelper
end
