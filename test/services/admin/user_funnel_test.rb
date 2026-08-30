# frozen_string_literal: true

require "test_helper"

class Admin::UserFunnelTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other = users(:two)
  end

  test "stage counts reflect cumulative milestones" do
    travel_to Time.zone.parse("2026-08-30 12:00:00") do
      @user.sessions.create!(updated_at: 1.day.ago)
      @user.sessions.create!(updated_at: Time.current)

      result = Admin::UserFunnel.call
      counts = result[:stage_counts]

      assert counts[:signed_up].positive?
      assert counts[:onboarding_complete].positive?
      assert counts[:returned_second_day] >= 1
    end
  end

  test "returned second day requires two distinct session activity days" do
    travel_to Time.zone.parse("2026-08-30 12:00:00") do
      @other.sessions.create!(updated_at: Time.current)

      row = Admin::UserFunnel.call[:rows].find { |entry| entry.user.id == @other.id }
      assert_nil row.returned_second_day_at
    end
  end

  test "inactive filter keeps users with no recent session activity" do
    travel_to Time.zone.parse("2026-08-30 12:00:00") do
      @user.sessions.create!(updated_at: 4.days.ago)
      @other.sessions.create!(updated_at: Time.current)

      rows = Admin::UserFunnel.call(filter: Admin::UserFunnel::FILTER_INACTIVE)[:rows]
      ids = rows.map { |row| row.user.id }

      assert_includes ids, @user.id
      assert_not_includes ids, @other.id
    end
  end

  test "first camp and first battle timestamps come from existing records" do
    area = life_areas(:one_self)
    journey = @user.life_journeys.first || @user.life_journeys.create!(
      life_area: area,
      title: "Ship",
      ideal_scene: "Shipped",
      current_reality: "Building",
      status: "active"
    )
    goal = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    camp = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )
    battle = @user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: camp, horizon: "day",
      title: "Battle", position: 0, scheduled_on: Date.current, completed_at: 1.hour.ago
    )

    row = Admin::UserFunnel.call[:rows].find { |entry| entry.user.id == @user.id }

    assert_equal camp.created_at.to_i, row.first_camp_planted_at.to_i
    assert_equal battle.completed_at.to_i, row.first_battle_won_at.to_i
  end

  test "sorts by last seen descending by default" do
    travel_to Time.zone.parse("2026-08-30 12:00:00") do
      @user.sessions.create!(updated_at: 1.day.ago)
      @other.sessions.create!(updated_at: Time.current)

      rows = Admin::UserFunnel.call(sort: "last_seen")[:rows]
      seen_ids = rows.filter_map { |row| row.user.id if row.last_seen_at.present? }

      assert_equal @other.id, seen_ids.first
    end
  end

  test "export_csv includes funnel columns" do
    csv = Admin::UserFunnel.export_csv(Admin::UserFunnel.call[:rows])
    assert_includes csv, "first_camp_planted_at"
    assert_includes csv, users(:one).email_address
  end

  test "excludes admin and developer accounts" do
    users(:admin)
    result = Admin::UserFunnel.call
    ids = result[:rows].map { |row| row.user.id }

    assert_not_includes ids, users(:admin).id
    assert_equal User.excluding_privileged.count, result[:rows].size
  end
end
