# frozen_string_literal: true

require "test_helper"

class Habits::QuickAddTest < ActiveSupport::TestCase
  test "derived matches mockup derived()" do
    assert_equal 1, Habits::QuickAdd.derived(target: 1)
    assert_equal 1, Habits::QuickAdd.derived(target: 3)
    assert_equal 5, Habits::QuickAdd.derived(target: 4)
    assert_equal 5, Habits::QuickAdd.derived(target: 10)
    assert_equal 5, Habits::QuickAdd.derived(target: 25)
    assert_equal 5, Habits::QuickAdd.derived(target: 50)
    assert_equal 10, Habits::QuickAdd.derived(target: 51)
    assert_equal 10, Habits::QuickAdd.derived(target: 200)
    assert_equal 100, Habits::QuickAdd.derived(target: 201)
    assert_equal 100, Habits::QuickAdd.derived(target: 2000)
    assert_equal 1000, Habits::QuickAdd.derived(target: 10_000)
  end

  test "suggestions matches mockup suggestions()" do
    assert_equal [ 1, 2, 3, 5 ], Habits::QuickAdd.suggestions(target: 2)
    assert_equal [ 1, 2, 3, 5 ], Habits::QuickAdd.suggestions(target: 5)
    assert_equal [ 1, 5, 10, 20 ], Habits::QuickAdd.suggestions(target: 20)
    assert_equal [ 5, 10, 25, 50 ], Habits::QuickAdd.suggestions(target: 25)
    assert_equal [ 5, 10, 25, 50 ], Habits::QuickAdd.suggestions(target: 100)
    assert_equal [ 50, 100, 250, 500 ], Habits::QuickAdd.suggestions(target: 101)
    assert_equal [ 50, 100, 250, 500 ], Habits::QuickAdd.suggestions(target: 2000)
    assert_equal [ 500, 1000, 2500, 5000 ], Habits::QuickAdd.suggestions(target: 10_000)
  end

  test "blank or non-positive target falls back to 1 and small chips" do
    assert_equal 1, Habits::QuickAdd.derived(target: nil)
    assert_equal 1, Habits::QuickAdd.derived(target: 0)
    assert_equal 1, Habits::QuickAdd.derived(target: -3)
    assert_equal [ 1, 2, 3, 5 ], Habits::QuickAdd.suggestions(target: nil)
    assert_equal [ 1, 2, 3, 5 ], Habits::QuickAdd.suggestions(target: 0)
  end
end
