# frozen_string_literal: true

require "test_helper"

class JourneySetupTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App in production",
      current_reality: "Still building",
      next_win: "Launch Beta",
      today_mission: "Write one test",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
  end

  test "journey climb shows clarity ring and locks next layer" do
    @journey.update!(
      purpose: nil, policy: nil, approach: nil, program: nil, finished_result: nil,
      setup_flags: { "goal" => "done" }
    )

    get life_journey_path(@journey)
    assert_response :success
    assert_match(/Climb clarity/i, response.body)
    assert_match(/Why it matters/i, response.body)
    assert_match(/Rules/i, response.body)
    assert_match(/Fill Why it matters to unlock/i, response.body)
    assert_select "#climb-purpose.lp-climb-card--open"
    assert_select "#climb-policy.lp-climb-card--locked"
  end

  test "saving goal unlocks purpose and raises clarity" do
    @journey.update!(
      purpose: nil, policy: nil, approach: nil, program: nil, finished_result: nil,
      next_win: nil, setup_flags: {}
    )

    patch life_journey_path(@journey), params: {
      layer: "goal",
      life_journey: { title: "Ship LifePoints" }
    }
    assert_redirected_to life_journey_path(@journey, edit: "purpose")
    follow_redirect!
    assert_response :success

    @journey.reload
    assert @journey.layer_done?("goal")
    assert @journey.layer_unlocked?("purpose")
    assert_equal :open, @journey.layer_state("purpose")
    assert_equal :locked, @journey.layer_state("policy")
    assert_equal 1, @journey.clarity_count
    assert_select "#climb-purpose.lp-climb-card--open"
  end

  test "skip purpose unlocks rules and counts toward clarity" do
    @journey.update!(setup_flags: { "goal" => "done" })

    patch life_journey_path(@journey), params: {
      layer: "purpose",
      skip: "1",
      life_journey: { purpose: "" }
    }
    assert_redirected_to life_journey_path(@journey, edit: "policy")

    @journey.reload
    assert @journey.layer_skipped?("purpose")
    assert @journey.layer_unlocked?("policy")
    assert_equal 2, @journey.clarity_count
  end

  test "cannot save purpose while goal flag incomplete" do
    @journey.update_column(:setup_flags, {})

    patch life_journey_path(@journey), params: {
      layer: "purpose",
      life_journey: { purpose: "Freedom" }
    }
    assert_redirected_to life_journey_path(@journey)
    @journey.reload
    assert_nil @journey.purpose.presence
    assert_not @journey.layer_done?("purpose")
  end

  test "blank purpose save does not unlock rules" do
    @journey.update!(setup_flags: { "goal" => "done" }, purpose: nil)

    patch life_journey_path(@journey), params: {
      layer: "purpose",
      life_journey: { purpose: "   " }
    }
    assert_redirected_to life_journey_path(@journey, edit: "purpose")
    @journey.reload
    assert_not @journey.layer_done?("purpose")
    assert_equal :locked, @journey.layer_state("policy")
  end

  test "cannot jump to rules before purpose filled or skipped" do
    @journey.update!(setup_flags: { "goal" => "done" })

    patch life_journey_path(@journey), params: {
      layer: "policy",
      life_journey: { policy: "Ship weekly" }
    }
    assert_redirected_to life_journey_path(@journey)
    @journey.reload
    assert_not @journey.layer_done?("policy")
    assert_equal :locked, @journey.layer_state("policy")
  end

  test "clarity count matches done plus skipped layers" do
    @journey.update!(
      setup_flags: {
        "goal" => "done",
        "purpose" => "skipped",
        "policy" => "done"
      }
    )
    assert_equal 3, @journey.clarity_count
    assert_equal LifeJourney::CLIMB_LAYERS.size, @journey.clarity_total
  end

  test "progress meter updates without climbing" do
    patch life_journey_path(@journey), params: {
      closer_only: "1",
      life_journey: { closer_percent: 40 }
    }
    assert_redirected_to life_journey_path(@journey)
    @journey.reload
    assert_in_delta 60.0, @journey.gap_percent.to_f, 0.01
  end

  test "milestone cannot be skipped" do
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done",
        "approach" => "done", "program" => "done"
      }
    )

    patch life_journey_path(@journey), params: {
      layer: "milestone",
      skip: "1",
      life_journey: { milestones: [ "" ] }
    }
    assert_redirected_to life_journey_path(@journey)
    @journey.reload
    assert_not @journey.layer_skipped?("milestone")
  end

  test "saving multiple approaches unlocks program and syncs legacy field" do
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done"
      },
      approach: nil, approaches: [], program: nil, programs: []
    )

    patch life_journey_path(@journey), params: {
      layer: "approach",
      life_journey: { approaches: [ "Build in public", "Coach + drills", "  " ] }
    }
    assert_redirected_to life_journey_path(@journey, edit: "program")
    @journey.reload
    assert_equal [ "Build in public", "Coach + drills" ], @journey.approaches_list
    assert_equal "Build in public", @journey.approach
    assert @journey.layer_done?("approach")
    assert @journey.layer_unlocked?("program")
  end

  test "blank approaches list is rejected" do
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done"
      },
      approaches: [], approach: nil
    )

    patch life_journey_path(@journey), params: {
      layer: "approach",
      life_journey: { approaches: [ " ", "" ] }
    }
    assert_redirected_to life_journey_path(@journey, edit: "approach")
    @journey.reload
    assert_not @journey.layer_done?("approach")
  end

  test "skip approach still unlocks program" do
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done"
      }
    )

    patch life_journey_path(@journey), params: {
      layer: "approach",
      skip: "1",
      life_journey: { approaches: [] }
    }
    assert_redirected_to life_journey_path(@journey, edit: "program")
    @journey.reload
    assert @journey.layer_skipped?("approach")
    assert @journey.layer_unlocked?("program")
  end

  test "saving multiple milestones syncs next_win to first" do
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done",
        "approach" => "done", "program" => "done"
      },
      milestones: [], next_win: nil
    )

    patch life_journey_path(@journey), params: {
      layer: "milestone",
      life_journey: { milestones: [ "Launch Beta", "First 10 users" ] }
    }
    assert_redirected_to life_journey_path(@journey, edit: "scenes")
    @journey.reload
    assert_equal [ "Launch Beta", "First 10 users" ], @journey.milestones_list
    assert_equal "Launch Beta", @journey.next_win
    assert @journey.layer_done?("milestone")
  end

  test "today layer creates multiple daily todos" do
    unlock_through_finished!
    @user.daily_todos.for_day.destroy_all

    patch life_journey_path(@journey), params: {
      layer: "today",
      life_journey: { today_mission: "Deep work block" },
      daily_todo_titles: [ "Write tests", "Ship UI polish", "  " ]
    }
    assert_redirected_to life_journey_path(@journey, edit: "today")
    @journey.reload
    assert @journey.layer_done?("today")

    titles = @user.daily_todos.for_day.ordered.pluck(:title)
    assert_equal [ "Write tests", "Ship UI polish" ], titles
    mission = @journey.missions.for_day.primary.order(:id).first
    assert_equal "Deep work block", mission.title
  end

  test "today layer rejects more than daily todo cap" do
    unlock_through_finished!
    @user.daily_todos.for_day.destroy_all
    too_many = Array.new(GameRules::MAX_DAILY_TODOS + 1) { |i| "Task #{i}" }

    patch life_journey_path(@journey), params: {
      layer: "today",
      daily_todo_titles: too_many
    }
    assert_redirected_to life_journey_path(@journey, edit: "today")
    assert_equal 0, @user.daily_todos.for_day.count
    @journey.reload
    assert_not @journey.layer_done?("today")
  end

  private

  def unlock_through_finished!
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done",
        "approach" => "done", "program" => "done", "milestone" => "done",
        "scenes" => "done", "finished" => "done"
      },
      finished_result: "A live product"
    )
  end
end
