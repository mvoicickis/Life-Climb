# frozen_string_literal: true

require "test_helper"

module Notifications
  class NudgeFallbackLineTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
    end

    test "morning line index uses user id and local julian day" do
      date = Date.new(2026, 8, 6)
      lines = I18n.t("notifications.morning_push.lines")
      expected = lines[(@user.id + date.jd) % lines.size]

      assert_equal expected, NudgeFallbackLine.for(user: @user, date: date, kind: :morning, locale: :en)
    end

    test "evening line index uses user id and local julian day" do
      date = Date.new(2026, 8, 6)
      lines = I18n.t("notifications.evening_push.lines")
      expected = lines[(@user.id + date.jd) % lines.size]

      assert_equal expected, NudgeFallbackLine.for(user: @user, date: date, kind: :evening, locale: :en)
    end

    test "consecutive local days never repeat the same morning line" do
      start = Date.new(2026, 8, 1)
      30.times do |offset|
        today = start + offset
        tomorrow = today + 1

        today_line = NudgeFallbackLine.for(user: @user, date: today, kind: :morning, locale: :en)
        tomorrow_line = NudgeFallbackLine.for(user: @user, date: tomorrow, kind: :morning, locale: :en)

        refute_equal today_line, tomorrow_line, "expected different lines for #{today} and #{tomorrow}"
      end
    end

    test "consecutive local days never repeat the same evening line" do
      start = Date.new(2026, 8, 1)
      30.times do |offset|
        today = start + offset
        tomorrow = today + 1

        today_line = NudgeFallbackLine.for(user: @user, date: today, kind: :evening, locale: :en)
        tomorrow_line = NudgeFallbackLine.for(user: @user, date: tomorrow, kind: :evening, locale: :en)

        refute_equal today_line, tomorrow_line, "expected different lines for #{today} and #{tomorrow}"
      end
    end

    test "different users can get different lines on the same day" do
      other = users(:two)
      date = Date.new(2026, 11, 22)

      a = NudgeFallbackLine.for(user: @user, date: date, kind: :morning, locale: :en)
      b = NudgeFallbackLine.for(user: other, date: date, kind: :morning, locale: :en)

      assert a.present?
      assert b.present?
      # Not asserting inequality — ids may collide modulo 10; rotation test covers day-to-day.
    end
  end
end