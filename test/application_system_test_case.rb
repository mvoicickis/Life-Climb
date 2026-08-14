require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Cards stay closed. Quest Space loads in ⋮ → Objectives.
  def open_project_objectives(project)
    card = find("#climb-path-project-#{project.id}")
    card.find(".lp-climb-path__menu-btn").click
    card.find(".lp-climb-path__menu:not([hidden]) .lp-climb-path__menu-item", text: "Objectives").click
    assert_selector "dialog#section-objectives-#{project.id}[open]", wait: 5
    within("dialog#section-objectives-#{project.id}") do
      assert_selector ".lp-climb-path__quest", wait: 5
    end
  end
end
