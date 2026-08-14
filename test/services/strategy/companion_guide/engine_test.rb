# frozen_string_literal: true

require "test_helper"

class Strategy::CompanionGuide::EngineTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "current starts at create_plan and persists companion_guide cursor" do
    step = Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey)

    assert_equal "create_plan", step.template_id
    assert_equal "create_plan", step.kind
    assert_match(/plan/i, step.question)

    cursor = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    assert_equal "in_progress", cursor["status"]
    assert_equal @goal.id, cursor["goal_id"]
    assert_equal "create_plan", cursor["template_id"]
  end

  test "variable-length walk builds plan projects and days then completes" do
    # Plan → tier → project A → 3 days → project B → 1 day → done
    answer!("Land interviews")
    answer!("steady")
    answer!("Polish resume")
    answer!("Rewrite summary")
    answer!("repeat")
    answer!("Update LinkedIn")
    answer!("repeat")
    answer!("Ask for one referral")
    answer!("advance") # continue_step → continue_project
    answer!("repeat") # continue_project → create_project
    answer!("Practice interviews")
    answer!("Do one mock interview")
    answer!("advance") # continue_step → continue_project
    result = answer!("advance") # done

    assert result.next_step.completed?
    assert_equal "completed", Strategy::CompanionGuide::Cursor.load(@journey.reload)["status"]

    plan = @goal.children.for_kind("plan").ordered.last
    assert_equal "Land interviews", plan.title
    assert_equal "steady", plan.effort_tier

    projects = plan.children.for_kind("project").ordered.to_a
    assert_equal 2, projects.size
    assert_equal "Polish resume", projects[0].title
    assert_equal "Practice interviews", projects[1].title

    days_a = days_under(projects[0])
    days_b = days_under(projects[1])
    assert_equal 3, days_a.size
    assert_equal 1, days_b.size
    assert_equal [ "Rewrite summary", "Update LinkedIn", "Ask for one referral" ], days_a.map(&:title)
    assert_equal [ "Do one mock interview" ], days_b.map(&:title)

    days_a.each do |day|
      assert_equal projects[0].id, day.parent_id, "day should hang on the path camp"
    end
  end

  test "resume mid-flow continues without duplicating records" do
    answer!("Land interviews")
    answer!("light")
    answer!("Polish resume")
    answer!("Rewrite summary")
    # Pause on continue_step after first day
    step = Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey.reload)
    assert_equal "continue_step", step.template_id
    assert_equal 1, step.step_count

    plan_count = @goal.children.for_kind("plan").count
    project_count = @goal.children.for_kind("plan").first.children.for_kind("project").count
    day_count = days_under(@goal.children.for_kind("plan").first.children.for_kind("project").first).size

    # Fresh engine instance (simulates new request)
    step2 = Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey.reload)
    assert_equal "continue_step", step2.template_id

    answer!("repeat")
    answer!("Update LinkedIn")

    assert_equal plan_count, @goal.children.for_kind("plan").count
    assert_equal project_count, @goal.reload.children.for_kind("plan").first.children.for_kind("project").count
    assert_equal day_count + 1, days_under(@goal.children.for_kind("plan").first.children.for_kind("project").first).size
  end

  test "idempotent re-answer on create_plan does not duplicate" do
    result1 = answer!("Land interviews")
    refute result1.noop?
    assert_equal 1, @goal.children.for_kind("plan").count

    # Rewind to create_plan with plan_id still set (double-submit / stuck cursor)
    data = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    data["template_id"] = "create_plan"
    data["answered_key"] = nil
    Strategy::CompanionGuide::Cursor.save!(@journey, data)

    result2 = answer!("Another title")
    assert result2.noop?
    assert_equal 1, @goal.children.for_kind("plan").count
    assert_equal "Land interviews", @goal.children.for_kind("plan").first.title
    assert_equal "set_effort_tier", result2.next_step.template_id
  end

  test "idempotent re-answer at same answered_key is a noop" do
    answer!("Land interviews")
    data = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    # Pretend we answered set_effort_tier already but did not advance
    data["template_id"] = "set_effort_tier"
    data["answered_key"] = Strategy::CompanionGuide::Cursor.cursor_key(data)
    Strategy::CompanionGuide::Cursor.save!(@journey, data)

    result = answer!("steady")
    assert result.noop?
    assert_nil @goal.children.for_kind("plan").first.reload.effort_tier
    assert_equal "create_project", result.next_step.template_id
  end

  test "step ceiling coerces repeat to advance without creating another day" do
    answer!("Land interviews")
    answer!("heavy")
    answer!("Only project")
    answer!("Only step")
    assert_equal "continue_step", Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey).template_id

    data = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    data["step_count"] = Strategy::CompanionGuide::Definition::MAX_STEPS_PER_PROJECT
    Strategy::CompanionGuide::Cursor.save!(@journey, data)

    project = @goal.children.for_kind("plan").first.children.for_kind("project").first
    before = days_under(project).size

    result = answer!("repeat")
    assert_equal "continue_project", result.next_step.template_id
    assert_equal before, days_under(project.reload).size
  end

  test "project ceiling coerces repeat to completed without creating another project" do
    answer!("Land interviews")
    answer!("steady")
    answer!("Project one")
    answer!("Step one")
    answer!("advance")

    data = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    assert_equal "continue_project", data["template_id"]
    data["project_count"] = Strategy::CompanionGuide::Definition::MAX_PROJECTS
    Strategy::CompanionGuide::Cursor.save!(@journey, data)

    plan = @goal.children.for_kind("plan").first
    before = plan.children.for_kind("project").count

    result = answer!("repeat")
    assert result.next_step.completed?
    assert_equal before, plan.reload.children.for_kind("project").count
  end

  test "returns nil current without a goal" do
    @goal.destroy!
    assert_nil Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey.reload)
  end

  test "current heals to create_project when mid-flow project was deleted" do
    answer!("Land interviews")
    answer!("steady")
    answer!("Polish resume")
    answer!("Rewrite summary")

    project = @goal.children.for_kind("plan").first.children.for_kind("project").first
    project.destroy!

    step = Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey.reload)
    assert_equal "create_project", step.template_id
    assert_equal I18n.t("strategy.companion_guide.shell.tree_changed"), step.notice

    cursor = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    assert_equal "create_project", cursor["template_id"]
    assert_nil cursor["project_id"]
    assert_equal @goal.children.for_kind("plan").first.id, cursor["plan_id"]
  end

  test "current heals to create_plan when plan was deleted" do
    answer!("Land interviews")
    answer!("steady")

    @goal.children.for_kind("plan").destroy_all

    step = Strategy::CompanionGuide::Engine.current(user: @user, journey: @journey.reload)
    assert_equal "create_plan", step.template_id
    assert step.notice.present?

    cursor = Strategy::CompanionGuide::Cursor.load(@journey.reload)
    assert_nil cursor["plan_id"]
    assert_nil cursor["project_id"]
  end

  test "companion guide i18n keys exist in all app locales" do
    %i[en de es lv ru].each do |locale|
      I18n.with_locale(locale) do
        assert I18n.t("strategy.companion_guide.questions.create_plan").present?, locale
        assert I18n.t("strategy.companion_guide.errors.blank_title").present?, locale
        assert I18n.t("strategy.companion_guide.shell.tree_changed").present?, locale
        refute_match(/translation missing/i, I18n.t("strategy.companion_guide.acks.0"))
      end
    end
  end

  private

  def answer!(value)
    Strategy::CompanionGuide::Engine.answer!(user: @user, journey: @journey.reload, value: value)
  end

  def days_under(project)
    project.children.for_kind("day").ordered.to_a
  end
end
