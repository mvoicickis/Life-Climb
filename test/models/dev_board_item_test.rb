# frozen_string_literal: true

require "test_helper"

class DevBoardItemTest < ActiveSupport::TestCase
  setup do
    @owner = users(:admin)
    @reporter = users(:one)
  end

  test "requires title and uses enum defaults" do
    item = DevBoardItem.new(owner: @owner, title: "Memory leak on Render")
    assert item.valid?
    item.save!
    assert_equal "bug", item.kind
    assert_equal "important", item.priority
    assert_equal "todo", item.status
  end

  test "rejects description over summary max" do
    item = DevBoardItem.new(
      owner: @owner,
      title: "Long write-up",
      description: "x" * (TextLimits::SUMMARY_MAX + 1)
    )
    assert_not item.valid?
    assert item.errors[:description].present?
  end

  test "rejects blank title" do
    item = DevBoardItem.new(owner: @owner, title: "")
    assert_not item.valid?
    assert_includes item.errors[:title], "can't be blank"
  end

  test "rejects invalid enum values" do
    item = DevBoardItem.new(
      owner: @owner,
      title: "Test",
      kind: "dragon",
      priority: "critical",
      status: "waiting"
    )
    assert_not item.valid?
    assert item.errors[:kind].present?
    assert item.errors[:priority].present?
    assert item.errors[:status].present?
  end

  test "reported_by is optional" do
    item = DevBoardItem.create!(
      owner: @owner,
      title: "Desktop layout",
      reported_by: @reporter
    )
    assert_equal @reporter, item.reported_by
    assert_equal @reporter.display_name, item.reported_by_label

    item.update!(reported_by: nil, reporter_note: "A beta tester")
    assert_equal "A beta tester", item.reported_by_label
  end
end
