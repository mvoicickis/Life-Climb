require "test_helper"
require "test_helpers/today_v2_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include TodayV2TestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Cards stay closed. Quest Space loads in ⋮ → Objectives.
  def open_project_objectives(project)
    open_mountain_list_fallback!
    card = find("#climb-path-project-#{project.id}", visible: :all)
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", card.native)
    menu_btn = card.find(".lp-climb-path__menu-btn", visible: :all)
    page.execute_script("arguments[0].click()", menu_btn.native)
    item = card.find(".lp-climb-path__menu:not([hidden]) .lp-climb-path__menu-item", text: "Objectives", visible: :all)
    page.execute_script("arguments[0].click()", item.native)
    assert_selector "dialog#section-objectives-#{project.id}[open]", wait: 5
    within("dialog#section-objectives-#{project.id}") do
      assert_selector ".lp-climb-path__quest", wait: 5
    end
  end

  # Mountain V4 keeps the legacy climb list off-canvas; open as an overlay for menus/tests.
  def open_mountain_list_fallback!
    return unless page.has_css?(".lp-trail__list-fallback", wait: 1)

    page.execute_script(<<~JS)
      (() => {
        const details = document.querySelector(".lp-trail__list-fallback");
        if (!details) return;
        details.classList.remove("sr-only");
        details.classList.add("is-test-open");
        details.open = true;
        details.scrollIntoView({ block: "nearest" });
      })()
    JS
    assert_selector ".lp-trail__list-fallback[open] .lp-climb-path", visible: :all, wait: 5
  end

  def assert_mountain_camp(project, text: nil, **opts)
    if page.has_css?("#trail-camp-#{project.id}", wait: 1)
      assert_selector "#trail-camp-#{project.id}", text: text, **opts
    else
      open_mountain_list_fallback!
      assert_selector "#climb-path-project-#{project.id}", text: text, visible: :all, **opts
    end
  end

  def open_trail_camp_sheet!(project)
    camp = find("#trail-camp-#{project.id}", visible: :all)
    page.execute_script(<<~JS, camp.native)
      const camp = arguments[0];
      camp.scrollIntoView({ block: "center" });
      const root = camp.closest("[data-controller~='trail-camp-sheet']");
      const sheet = root && root.querySelector("[data-trail-camp-sheet-target='sheet']");
      const body = root && root.querySelector("[data-trail-camp-sheet-target='body']");
      const title = root && root.querySelector("[data-trail-camp-sheet-target='title']");
      const accent = camp.dataset.accent || "#0f9488";
      if (root) root.style.setProperty("--lp-trail-accent", accent);
      if (title) title.textContent = camp.dataset.campTitle || "";
      if (body) {
        body.querySelectorAll("[data-camp-panel]").forEach((panel) => {
          const match = panel.dataset.campPanel === String(camp.dataset.campId);
          panel.hidden = !match;
          panel.toggleAttribute("hidden", !match);
        });
      }
      if (sheet) {
        sheet.querySelectorAll("[data-camp-menu-panel]").forEach((menu) => {
          const match = menu.dataset.campMenuPanel === String(camp.dataset.campId);
          menu.hidden = !match;
          menu.toggleAttribute("hidden", !match);
        });
        sheet.hidden = false;
        sheet.classList.add("is-open");
        sheet.setAttribute("aria-hidden", "false");
      }
    JS
    assert_selector ".lp-trail-sheet.is-open", wait: 5
    assert_selector "#trail-sheet-camp-#{project.id}:not([hidden])", visible: :all, wait: 5
  end

  def open_v4_plant_composer!
    page.execute_script(<<~JS)
      document.querySelector(".lp-dash-nav__fab")?.click();
    JS
    assert_selector ".lp-trail-plant.is-open, .lp-trail-plant:not([hidden])", wait: 5
  end
end
