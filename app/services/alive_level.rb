# Titles for how alive you are, from LifePoints total.
class AliveLevel
  LEVELS = [
    { min: 0, key: "spark" },
    { min: 50, key: "glow" },
    { min: 150, key: "flame" },
    { min: 400, key: "fire" },
    { min: 1000, key: "force" }
  ].freeze

  def initialize(points)
    @points = points.to_i
  end

  def key
    LEVELS.reverse.find { |level| @points >= level[:min] }.fetch(:key)
  end

  def title
    I18n.t("alive_levels.#{key}")
  end

  def current_min
    LEVELS.reverse.find { |level| @points >= level[:min] }.fetch(:min)
  end

  def next_min
    LEVELS.find { |level| level[:min] > @points }&.fetch(:min)
  end

  def next_level_hint
    if next_min
      I18n.t("studio.next_level", points: next_min)
    else
      I18n.t("studio.max_level")
    end
  end

  def progress
    current = LEVELS.reverse.find { |level| @points >= level[:min] }
    nxt = LEVELS.find { |level| level[:min] > @points }
    return 1.0 unless nxt

    span = nxt[:min] - current[:min]
    return 1.0 if span <= 0

    ((@points - current[:min]).to_f / span).clamp(0.0, 1.0)
  end

  def percent
    (progress * 100).round
  end

  def number
    LEVELS.index { |level| level[:key] == key }.to_i + 1
  end
end
