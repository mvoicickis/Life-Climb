# frozen_string_literal: true

require "test_helper"

class Habits::QuickAddStepsTest < ActiveSupport::TestCase
  test "band table matches mockup steps()" do
    assert_equal [ 1 ], Habits::QuickAddSteps.call(target: 1)
    assert_equal [ 1, 3 ], Habits::QuickAddSteps.call(target: 3)
    assert_equal [ 1, 5 ], Habits::QuickAddSteps.call(target: 4)
    assert_equal [ 1, 5 ], Habits::QuickAddSteps.call(target: 10)
    assert_equal [ 5, 10 ], Habits::QuickAddSteps.call(target: 20) # round(10/5)*5 → wait 20/2=10
    assert_equal [ 5, 25 ], Habits::QuickAddSteps.call(target: 50)
    assert_equal [ 10, 50 ], Habits::QuickAddSteps.call(target: 51)
    assert_equal [ 10, 50 ], Habits::QuickAddSteps.call(target: 200)
    assert_equal [ 50, 250 ], Habits::QuickAddSteps.call(target: 201)
    assert_equal [ 50, 250 ], Habits::QuickAddSteps.call(target: 2000)
    assert_equal [ 500, 2000 ], Habits::QuickAddSteps.call(target: 10_000)
  end

  test "blank or non-positive target falls back to 1 and 5" do
    assert_equal [ 1, 5 ], Habits::QuickAddSteps.call(target: nil)
    assert_equal [ 1, 5 ], Habits::QuickAddSteps.call(target: 0)
    assert_equal [ 1, 5 ], Habits::QuickAddSteps.call(target: -3)
  end
end
