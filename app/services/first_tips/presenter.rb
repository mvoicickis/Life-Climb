# frozen_string_literal: true

module FirstTips
  # Spotlight targets — matches approved cursor/first-tips-preview design.
  class Presenter
    HABIT_ADD_SELECTOR = "a.lp-dash-anytime__add-basic"

    SELECTORS = {
      "circle" => "#today-battlefield-rows .lp-today-v2-row:not(.is-won-row) .lp-today-v2-row__box:not(.is-won)",
      "mountain" => "nav.lp-dash-nav a[href*='/life_journeys/']",
      "camp" => "#mountain-trail .lp-trail-camp.is-current .lp-trail-camp__peg-visual",
      "habit" => ".lp-dash-anytime__toggle[data-today-habits-trigger]",
      "animal" => "#you-avatar-circle"
    }.freeze

    SHAPES = {
      "circle" => "circle",
      "animal" => "circle",
      "mountain" => "auto",
      "camp" => "auto",
      "habit" => "auto"
    }.freeze

    SIDES = {
      "circle" => "below",
      "habit" => "below",
      "animal" => "below",
      "mountain" => "above",
      "camp" => "above"
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