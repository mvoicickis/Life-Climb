# frozen_string_literal: true

require "test_helper"

class Today::DayCheerTest < ActiveSupport::TestCase
  test "bands escalate by percent" do
    assert_equal :idle, Today::DayCheer.call(percent: nil).band
    assert_equal :idle, Today::DayCheer.call(percent: 0).band
    assert_equal :moving, Today::DayCheer.call(percent: 10).band
    assert_equal :good_ground, Today::DayCheer.call(percent: 40).band
    assert_equal :close, Today::DayCheer.call(percent: 80).band
    assert_equal :met, Today::DayCheer.call(percent: 100).band
    assert_equal :over, Today::DayCheer.call(percent: 120).band
    assert_equal "over", Today::DayCheer.call(percent: 120).css
  end

  test "over message includes overshoot amount" do
    msg = Today::DayCheer.new(percent: 130).message
    assert_match(/30/, msg)
  end
end
