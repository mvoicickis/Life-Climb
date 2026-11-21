# frozen_string_literal: true

require "test_helper"

class HabitSigilHelperTest < ActionView::TestCase
  include ApplicationHelper

  HabitStub = Struct.new(:name, :unit, keyword_init: true)

  test "maps common habit types from name and unit with specific wins" do
    assert_equal "📖", habit_sigil(HabitStub.new(name: "Study", unit: "pages"))
    assert_equal "🗣", habit_sigil(HabitStub.new(name: "German Study", unit: "duo units"))
    assert_equal "💪", habit_sigil(HabitStub.new(name: "Push-Ups", unit: "reps"))
    assert_equal "💪", habit_sigil(HabitStub.new(name: "Push-Ups", unit: "times"))
    assert_equal "🥾", habit_sigil(HabitStub.new(name: "Walking", unit: "steps"))
    assert_equal "💧", habit_sigil(HabitStub.new(name: "Water", unit: "glasses"))
    assert_equal "🛏", habit_sigil(HabitStub.new(name: "Sleep", unit: "hours"))
    assert_equal "🧘", habit_sigil(HabitStub.new(name: "Meditation", unit: "minutes"))
    assert_equal "✍️", habit_sigil(HabitStub.new(name: "Journal", unit: "entries"))
    assert_equal "🌱", habit_sigil(HabitStub.new(name: "Mystery", unit: "units"))
  end

  test "habit_sigil_icon maps to lp_icon names never check" do
    assert_equal "book", habit_sigil_icon(HabitStub.new(name: "Study", unit: "pages"))
    assert_equal "drop", habit_sigil_icon(HabitStub.new(name: "Water", unit: "cups"))
    assert_equal "dumbbell", habit_sigil_icon(HabitStub.new(name: "Push-Ups", unit: "reps"))
    assert_equal "dumbbell", habit_sigil_icon(HabitStub.new(name: "Gym workout", unit: "times"))
    assert_equal "footsteps", habit_sigil_icon(HabitStub.new(name: "Walk", unit: "steps"))
    assert_equal "speech", habit_sigil_icon(HabitStub.new(name: "German", unit: "duo"))
    assert_equal "sprout", habit_sigil_icon(HabitStub.new(name: "Mystery", unit: "units"))
    refute_equal "check", habit_sigil_icon(HabitStub.new(name: "Mystery", unit: "units"))
  end
end
