# frozen_string_literal: true

require "test_helper"

module Notifications
  class PushGoalTitleTest < ActiveSupport::TestCase
    test "returns text unchanged when within limit" do
      text = "Get my driving license"
      assert_equal text, PushGoalTitle.truncate(text, limit: 40)
    end

    test "truncates long ascii at grapheme limit with ellipsis" do
      text = "a" * 50
      result = PushGoalTitle.truncate(text, limit: 40)
      assert_equal 41, result.each_grapheme_cluster.count
      assert result.end_with?("…")
    end

    test "keeps latvian goal intact when under limit" do
      text = "Iemācīties vācu valodu līdz B1"
      assert_equal text, PushGoalTitle.truncate(text, limit: 40)
    end

    test "does not split emoji grapheme when truncating" do
      text = "🎯" * 45
      result = PushGoalTitle.truncate(text, limit: 40)
      assert_equal 41, result.each_grapheme_cluster.count
      assert result.end_with?("…")
    end

    test "exactly at limit has no ellipsis" do
      text = "a" * 40
      assert_equal text, PushGoalTitle.truncate(text, limit: 40)
    end
  end
end
