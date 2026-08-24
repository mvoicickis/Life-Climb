# frozen_string_literal: true

# Places path projects on the Mountain V4 photo trail.
# Coordinates are fractions: x across the canvas, y down from the peak.
module MountainTrailHelper
  # Traced path on the default 1024×1536 mountain photo (yFrac, xFrac).
  TRAIL_CURVE = [
    [ 0.28, 0.525 ], [ 0.29, 0.526 ], [ 0.30, 0.548 ], [ 0.31, 0.570 ], [ 0.32, 0.582 ],
    [ 0.33, 0.572 ], [ 0.34, 0.553 ], [ 0.35, 0.560 ], [ 0.36, 0.584 ], [ 0.37, 0.589 ],
    [ 0.38, 0.572 ], [ 0.39, 0.553 ], [ 0.40, 0.535 ], [ 0.41, 0.553 ], [ 0.42, 0.564 ],
    [ 0.43, 0.578 ], [ 0.44, 0.567 ], [ 0.45, 0.537 ], [ 0.46, 0.503 ], [ 0.47, 0.477 ],
    [ 0.48, 0.483 ], [ 0.49, 0.545 ], [ 0.50, 0.573 ], [ 0.51, 0.585 ], [ 0.52, 0.570 ],
    [ 0.53, 0.528 ], [ 0.54, 0.493 ], [ 0.55, 0.463 ], [ 0.56, 0.472 ], [ 0.57, 0.517 ],
    [ 0.58, 0.563 ], [ 0.59, 0.585 ], [ 0.60, 0.588 ], [ 0.61, 0.565 ], [ 0.62, 0.531 ],
    [ 0.63, 0.500 ], [ 0.64, 0.476 ], [ 0.65, 0.479 ], [ 0.66, 0.497 ], [ 0.67, 0.498 ],
    [ 0.68, 0.563 ], [ 0.69, 0.595 ], [ 0.70, 0.606 ], [ 0.71, 0.593 ], [ 0.72, 0.567 ],
    [ 0.73, 0.532 ], [ 0.74, 0.503 ], [ 0.75, 0.535 ], [ 0.76, 0.578 ], [ 0.77, 0.578 ],
    [ 0.78, 0.582 ], [ 0.79, 0.598 ], [ 0.80, 0.618 ], [ 0.81, 0.618 ], [ 0.82, 0.601 ],
    [ 0.83, 0.575 ], [ 0.84, 0.532 ], [ 0.85, 0.509 ], [ 0.86, 0.496 ], [ 0.87, 0.458 ],
    [ 0.88, 0.440 ], [ 0.89, 0.411 ], [ 0.90, 0.412 ], [ 0.91, 0.433 ], [ 0.92, 0.446 ],
    [ 0.93, 0.451 ], [ 0.94, 0.487 ], [ 0.95, 0.502 ]
  ].freeze

  TRAIL_Y_MIN = 0.32
  TRAIL_Y_MAX = 0.88

  ACCENT_HEX = {
    "teal" => "#0f766e",
    "coral" => "#c2410c", # COLOR_KEYS uses coral
    "amber" => "#b45309",
    "purple" => "#7c3aed",
    "blue" => "#2563eb",
    "green" => "#15803d",
    "pink" => "#db2777",
    "gray" => "#57534e"
  }.freeze

  def mountain_trail_photo_url(journey)
    if journey&.mountain_photo&.attached?
      url_for(journey.mountain_photo.variant(resize_to_limit: [ 1200, 1800 ]))
    else
      image_path("mountain_trail_default.jpg")
    end
  rescue StandardError
    if journey&.mountain_photo&.attached?
      url_for(journey.mountain_photo)
    else
      image_path("mountain_trail_default.jpg")
    end
  end

  def mountain_trail_projects(trail)
    strategy_climb_path_nodes(trail).filter_map(&:record).reject(&:holding?)
  end

  # Returns { x:, y:, placed: } with x/y in 0..1 for CSS left/top %.
  def mountain_trail_slot(project, index:, total:)
    if project.trail_x.present? && project.trail_y.present?
      return {
        x: project.trail_x.to_f.clamp(0.05, 0.95),
        y: project.trail_y.to_f.clamp(TRAIL_Y_MIN, TRAIL_Y_MAX),
        placed: true
      }
    end

    y = auto_trail_y(index, total)
    { x: trail_x_for_y(y), y: y, placed: false }
  end

  def mountain_trail_accent(color_key)
    ACCENT_HEX.fetch(color_key.to_s, "#57534e")
  end

  def mountain_trail_ghosts(projects)
    slots = projects.each_with_index.map do |project, i|
      mountain_trail_slot(project, index: i, total: projects.size)
    end
    ys = slots.map { |s| s[:y] }.sort
    ghosts = []

    if ys.empty?
      return [ { x: trail_x_for_y(0.55), y: 0.55 } ]
    end

    if ys.first - TRAIL_Y_MIN > 0.14
      y = ((TRAIL_Y_MIN + ys.first) / 2.0).clamp(TRAIL_Y_MIN, TRAIL_Y_MAX)
      ghosts << { x: trail_x_for_y(y), y: y }
    end

    ys.each_cons(2) do |a, b|
      next unless (b - a) > 0.16

      y = ((a + b) / 2.0).clamp(TRAIL_Y_MIN, TRAIL_Y_MAX)
      ghosts << { x: trail_x_for_y(y), y: y }
    end

    if TRAIL_Y_MAX - ys.last > 0.14
      y = ((ys.last + TRAIL_Y_MAX) / 2.0).clamp(TRAIL_Y_MIN, TRAIL_Y_MAX)
      ghosts << { x: trail_x_for_y(y), y: y }
    end

    ghosts.first(3)
  end

  def mountain_trail_curve_json
    TRAIL_CURVE.to_json
  end

  private

  def auto_trail_y(index, total)
    return 0.58 if total <= 0

    t = total == 1 ? 0.5 : index.to_f / (total - 1)
    (TRAIL_Y_MIN + t * (TRAIL_Y_MAX - TRAIL_Y_MIN)).clamp(TRAIL_Y_MIN, TRAIL_Y_MAX)
  end

  def trail_x_for_y(y_frac)
    curve = TRAIL_CURVE
    return curve.first[1] if y_frac <= curve.first[0]
    return curve.last[1] if y_frac >= curve.last[0]

    (0...(curve.length - 1)).each do |i|
      y0, x0 = curve[i]
      y1, x1 = curve[i + 1]
      next unless y_frac >= y0 && y_frac <= y1

      k = (y_frac - y0) / (y1 - y0)
      return x0 + k * (x1 - x0)
    end

    0.5
  end
end
