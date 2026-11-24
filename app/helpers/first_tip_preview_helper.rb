# frozen_string_literal: true

# Development-only first-tip design preview (?tip=<key>). No production or test rendering.
module FirstTipPreviewHelper
  PREVIEW_KEYS = %w[circle mountain camp habit finish animal].freeze

  def first_tip_preview_key
    return unless Rails.env.development?
    return unless current_user

    key = params[:tip].to_s
    PREVIEW_KEYS.include?(key) ? key : nil
  end

  def first_tip_preview_page(key = first_tip_preview_key)
    case key
    when "circle", "mountain", "habit" then :today
    when "camp", "finish" then :mountain
    when "animal" then :you
    else nil
    end
  end

  def first_tip_preview_active?(page)
    key = first_tip_preview_key
    return false unless key

    first_tip_preview_page(key) == page
  end

  def first_tip_preview_config
    key = first_tip_preview_key
    return unless key
    return if key == "habit" && current_user.habits.active.on_home.exists?

    cfg = {
      key: key,
      selector: first_tip_preview_selector(key),
      shape: first_tip_preview_shape(key),
      side: first_tip_preview_bubble_side(key),
      pick: first_tip_preview_pick(key)
    }
    if key == "habit"
      cfg[:habit_add_selector] = "a.lp-dash-anytime__add-basic"
    end
    cfg
  end

  def first_tip_preview_guide_path(user = current_user)
    image_path(hero_animal_image_path(user))
  end

  private

  def first_tip_preview_selector(key)
    case key
    when "circle"
      "#today-battlefield-rows .lp-today-v2-row:not(.is-won-row) .lp-today-v2-row__box:not(.is-won)"
    when "mountain"
      "nav.lp-dash-nav a[href*='/life_journeys/']"
    when "camp"
      "#mountain-trail .lp-trail-camp.is-current .lp-trail-camp__peg-visual"
    when "habit"
      ".lp-dash-anytime__toggle[data-today-habits-trigger]"
    when "finish"
      "#mountain-trail .lp-trail-battles__row.is-open.is-check .lp-trail-battles__box:not(.is-won)"
    when "animal"
      "#you-avatar-circle"
    else
      ""
    end
  end

  def first_tip_preview_shape(key)
    case key
    when "circle", "finish", "animal" then "circle"
    when "mountain", "camp", "habit" then "auto"
    else "auto"
    end
  end

  def first_tip_preview_bubble_side(key)
    case key
    when "circle", "habit", "animal" then "below"
    else "above"
    end
  end

  def first_tip_preview_pick(key)
    key == "finish" ? "last" : "first"
  end
end
