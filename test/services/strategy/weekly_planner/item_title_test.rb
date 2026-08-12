# frozen_string_literal: true

require "test_helper"

class Strategy::WeeklyPlanner::ItemTitleTest < ActiveSupport::TestCase
  test "extracts plain strings unchanged" do
    assert_equal "Get a job", Strategy::WeeklyPlanner::ItemTitle.extract("Get a job")
  end

  test "extracts title from Hash and Parameters" do
    assert_equal "Get a job", Strategy::WeeklyPlanner::ItemTitle.extract("title" => "Get a job")
    params = ActionController::Parameters.new("title" => "Get a job")
    assert_equal "Get a job", Strategy::WeeklyPlanner::ItemTitle.extract(params)
  end

  test "unwraps Hash#to_s dump shape" do
    dumped = { "title" => "Get a job" }.to_s
    assert_equal '{"title" => "Get a job"}', dumped
    assert Strategy::WeeklyPlanner::ItemTitle.corrupted?(dumped)
    assert_equal "Get a job", Strategy::WeeklyPlanner::ItemTitle.extract(dumped)
  end

  test "does not treat normal titles with braces as corrupted" do
    refute Strategy::WeeklyPlanner::ItemTitle.corrupted?("Read {chapter} notes")
    assert_equal "Read {chapter} notes", Strategy::WeeklyPlanner::ItemTitle.extract("Read {chapter} notes")
  end
end
