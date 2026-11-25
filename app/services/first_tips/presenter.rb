# frozen_string_literal: true

module FirstTips
  # Spotlight targets — matches approved cursor/first-tips-preview design.
  class Presenter
    HABIT_ADD_SELECTOR = "a.lp-dash-anytime__add-basic"
    YOU_TAB_SELECTOR = 'nav.lp-dash-nav a.lp-dash-nav__link[href="/settings"]'
    CAMP_SHEET_ADD_SELECTOR = '.lp-trail-sheet.is-open [data-trail-battles-target="addRow"]'

    SELECTORS = {
      "circle" => "#today-battlefield-rows .lp-today-v2-row:not(.is-won-row) .lp-today-v2-row__box:not(.is-won)",
      "mountain" => "nav.lp-dash-nav a[href*='/life_journeys/']",
      "camp" => "#mountain-trail .lp-trail-camp.is-current .lp-trail-camp__peg-visual",
      "camp_sheet" => CAMP_SHEET_ADD_SELECTOR,
      "you_tab" => YOU_TAB_SELECTOR,
      "habit" => ".lp-dash-anytime__toggle[data-today-habits-trigger]",
      "animal" => "#you-avatar-circle"
    }.freeze

    SHAPES = {
      "circle" => "circle",
      "animal" => "circle",
      "mountain" => "auto",
      "camp" => "auto",
      "camp_sheet" => "auto",
      "you_tab" => "auto",
      "habit" => "auto"
    }.freeze

    SIDES = {
      "circle" => "below",
      "habit" => "below",
      "animal" => "below",
      "mountain" => "above",
      "camp" => "above",
      "camp_sheet" => "above",
      "you_tab" => "above"
    }.freeze

    class << self
      def config_for(key)
        key = key.to_s
        cfg = {
          key: key,
          selector: SELECTORS.fetch(key),
          shape: SHAPES.fetch(key),
          side: SIDES.fetch(key),
          pick: "first"
        }
        cfg[:habit_add_selector] = HABIT_ADD_SELECTOR if key == "habit"
        cfg
      end
    end
  end
end
