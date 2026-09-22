# frozen_string_literal: true

require "test_helper"

class MountainTrailMapTentStylesTest < ActiveSupport::TestCase
  setup do
    @css = Rails.root.join("app/assets/stylesheets/mountain_trail.css").read
  end

  test "map tent uses css triangle not webp img rules" do
    refute_match(/\.lp-trail\.is-v4 \.lp-trail-camp\.is-map-tent \.lp-trail-camp__tent-img/, @css)
    assert_includes @css, ".lp-trail.is-v4 .lp-trail-camp.is-map-tent .lp-trail-camp__tent"
    assert_includes @css, "--lp-tent-emblem-anchor-x: 0.75"
    refute_match(/\.lp-trail-camp__ring[\s\S]*vector-effect:\s*non-scaling-stroke/, @css)
  end

  test "done badge uses surface border on map tents" do
    assert_match(
      /\.lp-trail\.is-v4 \.lp-trail-camp\.is-map-tent \.lp-trail-camp__cleared[\s\S]*border:\s*2px solid var\(--lp-surface/,
      @css
    )
  end
end
