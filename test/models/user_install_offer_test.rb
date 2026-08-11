# frozen_string_literal: true

require "test_helper"

class UserInstallOfferTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(
      install_offer_dismiss_count: 0,
      install_offer_dismissed_at: nil,
      install_offer_installed_at: nil
    )
    @user.daily_todos.delete_all
  end

  test "battle_won_once requires a completed DailyTodo" do
    refute @user.battle_won_once?

    @user.daily_todos.create!(
      title: "First win",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 0,
      completed_at: Time.current
    )

    assert @user.battle_won_once?
  end

  test "eligible after first win with zero dismissals" do
    refute @user.install_offer_eligible?

    complete_one_battle!
    assert @user.install_offer_eligible?
  end

  test "ineligible until 30 days after first dismiss" do
    travel_to Time.zone.parse("2026-01-01 12:00:00") do
      complete_one_battle!
      @user.mark_install_offer_dismissed!

      assert_equal 1, @user.reload.install_offer_dismiss_count
      refute @user.install_offer_eligible?
    end

    travel_to Time.zone.parse("2026-01-30 12:00:00") do
      refute @user.install_offer_eligible?
    end

    travel_to Time.zone.parse("2026-01-31 12:00:00") do
      assert @user.install_offer_eligible?
    end
  end

  test "never eligible after two dismissals" do
    travel_to Time.zone.parse("2026-01-01 12:00:00") do
      complete_one_battle!
      @user.mark_install_offer_dismissed!
    end

    travel_to Time.zone.parse("2026-02-01 12:00:00") do
      assert @user.install_offer_eligible?
      @user.mark_install_offer_dismissed!
      assert_equal 2, @user.reload.install_offer_dismiss_count
      refute @user.install_offer_eligible?
    end

    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      refute @user.install_offer_eligible?
    end
  end

  test "install sets installed_at and leaves dismiss_count unchanged" do
    complete_one_battle!
    @user.mark_install_offer_dismissed!
    count_before = @user.reload.install_offer_dismiss_count

    @user.mark_install_offer_installed!

    assert @user.reload.install_offer_installed_at.present?
    assert_equal count_before, @user.install_offer_dismiss_count
    refute @user.install_offer_eligible?
  end

  test "installed blocks eligibility even with zero dismissals" do
    complete_one_battle!
    @user.mark_install_offer_installed!
    refute @user.install_offer_eligible?
  end

  private

  def complete_one_battle!
    @user.daily_todos.create!(
      title: "Won battle",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 0,
      completed_at: Time.current
    )
  end
end
