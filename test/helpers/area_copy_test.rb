# frozen_string_literal: true

require "test_helper"

class AreaCopyTest < ActiveSupport::TestCase
  test "relationships purpose placeholder is love-specific" do
    text = AreaCopy.for("relationships", "purpose_placeholder")
    assert_match(/safe|together|drifting|relationship/i, text)
    assert_no_match(/Rails|portfolio/i, text)
  end

  test "career approach placeholder stays craft-specific" do
    text = AreaCopy.for("career", "approach_placeholder")
    assert_match(/Build|Coach|client|public/i, text)
  end

  test "falls back to journeys.sections when area key missing field" do
    text = AreaCopy.for("relationships", "progress_hint")
    assert_match(/close|0|100|feel/i, text)
  end
end
