# frozen_string_literal: true

require "test_helper"

class TrailCampCompletedCardTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
  end

  def win_all_battles!(project)
    project.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "day",
      title: "Solo",
      scheduled_on: Date.current,
      position: 0
    ).tap { |battle| battle.update!(completed_at: Time.current) }
  end

  test "finish camp turbo stream shows completed card and refreshes map without replacing battles" do
    camp_a = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Camp Alpha", position: 0, stage: 0
    )
    camp_b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Camp Beta", position: 1, stage: 1
    )
    win_all_battles!(camp_a)

    post strategy_goal_manual_completion_path(camp_a), as: :turbo_stream
    assert_response :success

    assert_match %(action="replace" target="trail-camp-finish-#{camp_a.id}"), response.body
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.finished"), response.body
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.next_camp", name: camp_b.title), response.body
    assert_match %(data-camp-id="#{camp_b.id}"), response.body
    assert_match %(action="replace" target="trail-map-camps"), response.body
    refute_match %(action="replace" target="trail-battles-#{camp_a.id}"), response.body

    assert camp_a.reload.manually_completed?
    refute camp_b.reload.completed?
    refute_includes response.body, I18n.t("strategy.rpg.trail.finish_camp_card.next_camp", name: camp_a.title)
  end

  test "undo turbo stream restores finish prompt and reopens camp" do
    camp = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Solo camp", position: 0
    )
    win_all_battles!(camp)
    post strategy_goal_manual_completion_path(camp), as: :turbo_stream
    assert camp.reload.manually_completed?

    delete strategy_goal_manual_completion_path(camp), as: :turbo_stream
    assert_response :success

    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.title"), response.body
    refute_match I18n.t("strategy.rpg.trail.finish_camp_card.finished"), response.body
    refute camp.reload.manually_completed?
    refute camp.completed?
  end

  test "last open camp shows back to mountain" do
    camp = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Final camp", position: 0
    )
    win_all_battles!(camp)

    post strategy_goal_manual_completion_path(camp), as: :turbo_stream
    assert_response :success
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.back_to_mountain"), response.body
    refute_match %(data-camp-id=), response.body
  end

  test "next open camp after finish is not the finished camp and map stream targets it" do
    camps = 4.times.map do |i|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
        title: "Camp #{i}", position: i, stage: i
      )
    end
    win_all_battles!(camps[0])

    post strategy_goal_manual_completion_path(camps[0]), as: :turbo_stream
    assert_response :success
    next_camp = camps[1]
    assert_match %(data-camp-id="#{next_camp.id}"), response.body
    assert_match %(action="replace" target="trail-map-camps"), response.body
    refute next_camp.reload.completed?
    refute_equal camps[0].id, next_camp.id
    refute_match I18n.t("strategy.rpg.trail.finish_camp_card.next_camp", name: camps[0].title), response.body
  end
end
