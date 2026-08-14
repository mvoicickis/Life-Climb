# frozen_string_literal: true

require "test_helper"

class Today::CommitmentTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @journey = seed_climb!(@user)
    Today::Commitment.apply_preset!(@journey, "easy")
  end

  test "migration defaults leave existing journeys on Easy 1/1" do
    assert_equal "easy", @journey.commitment_key
    assert_equal "Easy", @journey.commitment_name
    assert_equal 1, @journey.commitment_habit_count
    assert_equal 1, @journey.commitment_battle_count
  end

  test "camp_capacity counts incomplete path camps and ignores completed and nil journey" do
    assert_equal 0, Today::Commitment.camp_capacity(nil)

    # seed_climb! creates one incomplete path camp → 1
    assert_equal 1, Today::Commitment.camp_capacity(@journey)

    goal = @user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
    plan = goal.children.for_kind("plan").ordered.first

    path_a = plan.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Bare path A", position: 10
    )
    path_b = plan.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Bare path B", position: 11
    )
    assert path_a.path_level_camp?
    assert path_b.path_level_camp?
    assert_equal 3, Today::Commitment.camp_capacity(@journey)

    path_a.update!(completed_at: Time.current)
    assert_equal 2, Today::Commitment.camp_capacity(@journey)
  end

  test "eligible_for Easy always; Medium needs 3 habits and 3 camps" do
    assert Today::Commitment.eligible_for?(user: @user, key: "easy", journey: @journey)
    assert Today::Commitment.eligible_for?(user: @user, key: "easy", journey: nil)

    elig = Today::Commitment.eligibility(user: @user, key: "medium", journey: @journey)
    assert_not elig.eligible?
    assert elig.missing_habits
    assert elig.missing_camps

    seed_today_habits!(3)
    elig = Today::Commitment.eligibility(user: @user, key: "medium", journey: @journey)
    assert_not elig.eligible?
    assert_not elig.missing_habits
    assert elig.missing_camps

    ensure_camp_capacity!(3)
    assert Today::Commitment.eligible_for?(user: @user, key: "medium", journey: @journey)
  end

  test "counts only timed completed battles and requires full N/N" do
    habit = @user.habits.create!(
      name: "Water", unit: "glasses", points: 5, frequency: "daily",
      active: true, show_on_home: true, quantity_checkin: false
    )
    habit.completions.create!(user: @user, completed_on: Date.current, points_awarded: habit.points)

    timed = @user.daily_todos.create!(
      title: "Timed fight", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, start_time: "09:00", end_time: "10:00", position: 1
    )
    @user.daily_todos.create!(
      title: "Untimed fight", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, position: 2
    )

    # Selection gate is separate — set Medium counts directly to assert progress math.
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    progress = Today::Commitment.progress(user: @user, journey: @journey)

    assert_equal 1, progress.habit_done
    assert_equal 3, progress.habit_required
    assert_equal 1, progress.battle_done
    assert_equal 3, progress.battle_required
    assert_includes progress.battle_ids, timed.id
    assert_not progress.met?

    Today::Commitment.apply_preset!(@journey, "easy")
    easy = Today::Commitment.progress(user: @user, journey: @journey.reload)
    assert easy.met?
  end

  test "untimed completed battles are ignored" do
    @user.daily_todos.create!(
      title: "Loose card", scheduled_on: Date.current, aspect_key: "career",
      completed_at: Time.current, position: 1
    )
    progress = Today::Commitment.progress(user: @user, journey: @journey)
    assert_equal 0, progress.battle_done
  end

  test "apply_preset and level_up refuse ineligible upgrades; same-tier reapply allowed" do
    assert_raises(Today::Commitment::IneligibleError) do
      Today::Commitment.apply_preset!(@journey, "medium")
    end
    assert_equal "easy", @journey.reload.commitment_key

    Today::Commitment.apply_preset!(@journey, "easy")
    assert_equal "easy", @journey.reload.commitment_key

    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    Today::Commitment.apply_preset!(@journey, "medium")
    assert_equal "medium", @journey.reload.commitment_key

    assert_not Today::Commitment.level_up_preset!(@journey)
    assert_equal "medium", @journey.reload.commitment_key
  end

  test "no demotion when habits drop after already on Medium" do
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    @user.habits.active.on_home.destroy_all
    @journey.update!(updated_at: Time.current)
    assert_equal "medium", @journey.reload.commitment_key
    assert_equal 3, @journey.commitment_habit_count
  end

  test "suggest_level_up false when next tier ineligible despite streak; true when eligible" do
    seed_today_habits!(1)
    @journey.update!(
      commitment_met_streak_days: 3,
      commitment_met_on: Date.current,
      commitment_level_up_declined_on: nil
    )
    assert_not Today::Commitment.suggest_level_up?(journey: @journey)

    seed_today_habits!(3)
    ensure_camp_capacity!(3)
    assert Today::Commitment.suggest_level_up?(journey: @journey.reload)
  end

  test "touch_met_streak increments on consecutive met days and suggests level up when eligible" do
    seed_today_habits!(3)
    ensure_camp_capacity!(3)

    habit = @user.habits.active.on_home.where(quantity_checkin: false).first!
    3.times do |offset|
      date = Date.current - (2 - offset)
      habit.completions.find_or_create_by!(completed_on: date) do |completion|
        completion.user = @user
        completion.points_awarded = habit.points
      end
      @user.daily_todos.create!(
        title: "Fight #{date}", scheduled_on: date, aspect_key: "career",
        completed_at: Time.zone.parse("#{date} 10:00"),
        start_time: "09:00", end_time: "10:00", position: 200 + offset
      )
      Today::Commitment.touch_met_streak!(user: @user, journey: @journey.reload, date: date)
    end

    @journey.reload
    assert_equal 3, @journey.commitment_met_streak_days
    assert Today::Commitment.suggest_level_up?(journey: @journey)

    Today::Commitment.decline_level_up!(@journey)
    assert_not Today::Commitment.suggest_level_up?(journey: @journey.reload)

    @journey.update!(commitment_level_up_declined_on: nil)
    assert Today::Commitment.level_up_preset!(@journey)
    assert_equal "medium", @journey.reload.commitment_key
    assert_equal 3, @journey.commitment_habit_count
  end

  test "gap_alert joins habit and camp sentences like Settings flash" do
    @user.habits.active.on_home.update_all(show_on_home: false)
    elig = Today::Commitment.eligibility(user: @user, key: "medium", journey: @journey)
    alert = Today::Commitment.gap_alert(elig)
    assert_equal(
      "Medium needs #{elig.habit_need} Today habits — you have #{elig.habit_have}. " \
      "Medium needs #{elig.camp_need} planned camps — you have #{elig.camp_have}.",
      alert
    )
  end

  test "setup_gap nil when habits and timed battles cover the tier" do
    seed_today_habits!(1)
    @user.daily_todos.create!(
      title: "Timed fight", scheduled_on: Date.current, aspect_key: "career",
      start_time: "09:00", end_time: "10:00", position: 1
    )

    assert_nil Today::Commitment.setup_gap(user: @user, journey: @journey)
  end

  test "setup_gap habits when on_home habits are short" do
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.create!(
      title: "Loose fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    gap = Today::Commitment.setup_gap(user: @user, journey: @journey)
    assert_equal :habits, gap.kind
    assert_equal 0, gap.habit_have
    assert_equal 1, gap.habit_need
  end

  test "setup_gap battles when todo count is short" do
    seed_today_habits!(1)
    @user.daily_todos.for_day(Date.current).destroy_all

    gap = Today::Commitment.setup_gap(user: @user, journey: @journey)
    assert_equal :battles, gap.kind
    assert_equal 0, gap.battle_have
    assert_equal 1, gap.battle_need
  end

  test "setup_gap set_time when an untimed todo blocks the battle target" do
    seed_today_habits!(1)
    @user.daily_todos.for_day(Date.current).destroy_all
    todo = @user.daily_todos.create!(
      title: "Untimed fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0) do
      gap = Today::Commitment.setup_gap(user: @user, journey: @journey)
      assert_equal :set_time, gap.kind
      assert_equal todo.id, gap.todo.id
    end
  end

  test "setup_gap prefers habits over set_time when both apply" do
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.create!(
      title: "Untimed fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    gap = Today::Commitment.setup_gap(user: @user, journey: @journey)
    assert_equal :habits, gap.kind
  end

  test "setup_gap skips set_time at or after overdue hour" do
    seed_today_habits!(1)
    @user.daily_todos.create!(
      title: "Untimed fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    travel_to Time.zone.local(
      Date.current.year, Date.current.month, Date.current.day,
      Strategy::NextAction::OVERDUE_AFTER_HOUR, 0, 0
    ) do
      assert_nil Today::Commitment.setup_gap(user: @user, journey: @journey)
    end
  end

  test "setup_gap still returns habits after overdue hour" do
    @user.habits.active.on_home.destroy_all

    travel_to Time.zone.local(
      Date.current.year, Date.current.month, Date.current.day,
      Strategy::NextAction::OVERDUE_AFTER_HOUR + 2, 0, 0
    ) do
      gap = Today::Commitment.setup_gap(user: @user, journey: @journey)
      assert_equal :habits, gap.kind
    end
  end

  test "setup_gap nil when timed count already meets need despite extra untimed" do
    seed_today_habits!(1)
    @user.daily_todos.create!(
      title: "Timed fight", scheduled_on: Date.current, aspect_key: "career",
      start_time: "09:00", end_time: "10:00", position: 1
    )
    @user.daily_todos.create!(
      title: "Extra untimed", scheduled_on: Date.current, aspect_key: "career",
      position: 2
    )

    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0) do
      assert_nil Today::Commitment.setup_gap(user: @user, journey: @journey)
    end
  end

  private

  def seed_today_habits!(count)
    have = @user.habits.active.on_home.count
    (have + 1).upto(count) do |n|
      @user.habits.create!(
        name: "Habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
  end

  def ensure_camp_capacity!(needed)
    while Today::Commitment.camp_capacity(@journey) < needed
      goal = @user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
      plan = goal.children.for_kind("plan").ordered.first
      plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project",
        title: "Bare camp #{SecureRandom.hex(3)}",
        position: plan.children.maximum(:position).to_i + 1
      )
    end
  end
end
