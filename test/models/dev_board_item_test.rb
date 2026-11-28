# frozen_string_literal: true

require "test_helper"

class DevBoardItemTest < ActiveSupport::TestCase
  setup do
    @owner = users(:admin)
    @checker = User.create!(
      email_address: "karen@example.com",
      name: "Karen",
      referral_code: "fixtkaren",
      password: "password12345",
      admin: true,
      onboarding_completed_at: Time.current,
      home_stat_count: 6
    )
    @admins = [@owner, @checker].sort_by(&:id)
    @reporter = users(:one)
  end

  def create_item!(status:, owner: @owner, **attrs)
    DevBoardItem.create!(
      { title: "Board item", owner: owner, reported_by: @owner, status: status }.merge(attrs)
    )
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

  test "move start sends item to doing" do
    item = create_item!(status: :todo)
    assert item.move!(to: "start", actor: @owner, admins: @admins)
    assert item.doing?
  end

  test "move send_to_check hands off to other admin" do
    item = create_item!(status: :doing, owner: @owner)
    assert item.move!(to: "send_to_check", actor: @owner, admins: @admins)
    item.reload
    assert item.needs_check?
    assert_equal @checker, item.owner
    assert_equal @owner.id, item.work_owner_id
  end

  test "move looks good marks done and clears check note" do
    item = create_item!(
      status: :needs_check,
      owner: @checker,
      work_owner_id: @owner.id,
      check_note: "Old feedback"
    )
    assert item.move!(to: "looks_good", actor: @checker, admins: @admins)
    item.reload
    assert item.done?
    assert item.done_at.present?
    assert_nil item.work_owner_id
    assert_nil item.check_note
  end

  test "move not_yet sends back to doer with note" do
    item = create_item!(status: :needs_check, owner: @checker, work_owner_id: @owner.id)
    assert item.move!(to: "not_yet", actor: @checker, admins: @admins, check_note: "Fix padding")
    item.reload
    assert item.doing?
    assert_equal @owner, item.owner
    assert_equal "Fix padding", item.check_note
    assert_nil item.work_owner_id
  end

  test "move not_yet rejects blank note" do
    item = create_item!(status: :needs_check, owner: @checker, work_owner_id: @owner.id)
    assert_not item.move!(to: "not_yet", actor: @checker, admins: @admins, check_note: "  ")
    assert_includes item.errors[:check_note], "can't be blank"
    assert item.needs_check?
  end

  test "move later from todo" do
    item = create_item!(status: :todo)
    assert item.move!(to: "later", actor: @owner, admins: @admins)
    assert item.later?
  end

  test "move later from doing" do
    item = create_item!(status: :doing)
    assert item.move!(to: "later", actor: @owner, admins: @admins)
    assert item.later?
  end

  test "move later is not allowed from needs check" do
    item = create_item!(status: :needs_check, owner: @checker, work_owner_id: @owner.id)
    assert_not item.move!(to: "later", actor: @checker, admins: @admins)
    assert item.needs_check?
  end

  test "move to todo from later" do
    item = create_item!(status: :later)
    assert item.move!(to: "move_to_todo", actor: @owner, admins: @admins)
    assert item.todo?
  end

  test "disallowed move is rejected" do
    item = create_item!(status: :todo)
    assert_not item.move!(to: "looks_good", actor: @owner, admins: @admins)
    assert item.todo?
    assert item.errors[:base].present?
  end
end