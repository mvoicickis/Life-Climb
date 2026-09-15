# frozen_string_literal: true

require "test_helper"

class MountainTrailMapGeometryTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
  end

  test "v4 surface uses map aspect ratio not fixed 1180px photo height" do
    refute_match(/--lp-trail-photo-h:\s*1180px/, @css)

    surface = @css[/\.lp-trail\.is-v4 \.lp-trail__surface\s*\{[^}]+\}/m]
    assert surface, "expected .lp-trail.is-v4 .lp-trail__surface block"
    assert_match(/aspect-ratio:\s*var\(--map-aspect,\s*2\s*\/\s*3\)/, surface)
    assert_match(/container-type:\s*size/, surface)
    assert_match(/--lp-trail-photo-h:\s*100cqh/, surface)
  end

  test "v4 photo fills 2:3 frame without cover crop" do
    photo = @css[/\.lp-trail\.is-v4 img\.lp-trail__photo\s*\{[^}]+\}/m]
    assert photo, "expected v4 .lp-trail__photo block"
    assert_match(/object-fit:\s*contain/, photo)
    refute_match(/object-fit:\s*cover/, photo)
  end

  test "custom mountain photo uses blurred backdrop bleed behind contain" do
    assert_includes @css, ".lp-trail.is-v4 .lp-trail__photo-backdrop"
    assert_includes @css, ".lp-trail.is-v4.is-custom-mountain-photo img.lp-trail__photo"

    backdrop = @css[/\.lp-trail\.is-v4 \.lp-trail__photo-backdrop\s*\{[^}]+\}/m]
    assert backdrop, "expected photo backdrop block"
    assert_match(/object-fit:\s*cover/, backdrop)
    assert_match(/blur\(/, backdrop)
    assert_match(/scale\(/, backdrop)
  end

  test "v4 map fills aspect surface instead of legacy mountain class" do
    map = @css[/\.lp-trail\.is-v4 \.lp-trail__map\s*\{[^}]+\}/m]
    assert map, "expected .lp-trail.is-v4 .lp-trail__map block"
    assert_match(/position:\s*absolute/, map)
    refute_match(/\.lp-trail\.is-v4 \.lp-trail__mountain\s*\{[^}]*height:\s*var\(--lp-trail-photo-h\)/m, @css)
  end
end
