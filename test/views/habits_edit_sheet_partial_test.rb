# frozen_string_literal: true

require "test_helper"

class HabitsEditSheetPartialTest < ActionView::TestCase
  include ClimbTestHelper

  setup do
    enable_habits!
    @user = users(:one)
    @journey = seed_climb!(@user, today_mission: "Partial")
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @habit = @user.habits.create!(
      name: "Stretch",
      unit: "times",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      quantity_checkin: true,
      quick_add_amount: 5,
      life_journey_id: @journey.id
    )
  end

  test "initial render shows delete link and keeps confirm copy inside template only" do
    html = render(
      partial: "habits/edit_sheet",
      locals: {
        habit: @habit,
        return_to: "mountain",
        journey: @journey,
        goal: @goal,
        plan: @plan,
        sheet_target: true
      }
    )

    confirm = I18n.t("habits.basic_edit.delete_confirm")
    assert_includes html, I18n.t("habits.basic_edit.delete_basic")
    assert_match(/<template[^>]+data-basic-edit-sheet-target="confirmTemplate"/, html)
    assert_includes html, confirm

    doc = Nokogiri::HTML.fragment(html)
    visible_confirms = doc.css("p").reject { |node| node.ancestors("template").any? }
    assert_empty visible_confirms.map(&:text).select { |text| text.include?(confirm) }
  end
end
