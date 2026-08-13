# frozen_string_literal: true

require "test_helper"

class Today::NoticeStackTest < ActiveSupport::TestCase
  test "always includes next_action when present and caps at two" do
    shown = Today::NoticeStack.call(
      next_action: true,
      human_win: true,
      level_up: true,
      shield_tip: true,
      install_offer: true
    )
    assert_equal %i[next_action human_win], shown
  end

  test "fills second slot by priority when next_action present" do
    shown = Today::NoticeStack.call(
      next_action: true,
      human_win: false,
      level_up: true,
      shield_tip: true,
      install_offer: true
    )
    assert_equal %i[next_action level_up], shown
  end

  test "without next_action still caps at two" do
    shown = Today::NoticeStack.call(
      next_action: false,
      human_win: false,
      level_up: true,
      shield_tip: true,
      install_offer: true
    )
    assert_equal %i[level_up shield_tip], shown
  end
end
