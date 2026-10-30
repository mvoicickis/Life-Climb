# frozen_string_literal: true

require "test_helper"

class WorldsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(planning_version: 2, onboarding_completed_at: Time.current)
    sign_in_as @user
    allow_extra_climbs!(@user)
  end

  test "show lists eight rings groups goals and hides zero counts" do
    me_journey = seed_climb!(@user, area_key: "self", title: "Sleep by 11", today_mission: "Lights out")
    work_journey = seed_second_journey!(
      title: "Ship the app",
      area_key: "career",
      battle_title: "Write tests"
    )
    other = users(:two)
    other.update!(planning_version: 2, onboarding_completed_at: Time.current)
    allow_extra_climbs!(other)
    seed_climb!(other, area_key: "self", title: "Other world goal", today_mission: "Foreign battle")

    get world_path
    assert_response :success

    assert_select ".lp-my-world-list__row", count: 8
    LifeArea::WORLD_RINGS.each do |ring|
      assert_select ".lp-my-world-list__row[data-ring=?]", ring
      assert_select ".lp-my-world-sheet[data-ring=?]", ring
    end

    assert_select ".lp-my-world-list__row[data-ring=me] .lp-my-world-list__count",
                  text: I18n.t("my_world.goals_count", count: 1)
    assert_select ".lp-my-world-list__row[data-ring=friends_work] .lp-my-world-list__count",
                  text: I18n.t("my_world.goals_count", count: 1)
    assert_select ".lp-my-world-list__row[data-ring=family_love] .lp-my-world-list__count", count: 0
    assert_select ".lp-my-world-list__count", text: /0 goal/, count: 0

    assert_select ".lp-my-world-sheet[data-ring=me] .lp-my-world-sheet__mtn-title", text: me_journey.title
    assert_select ".lp-my-world-sheet[data-ring=friends_work] .lp-my-world-sheet__mtn-title", text: work_journey.title
    assert_select ".lp-my-world-sheet__mtn-title", text: "Other world goal", count: 0

    assert_select "a.lp-my-world__back[href=?]", life_journey_path(me_journey)
    assert_select "h1.lp-my-world__title", text: I18n.t("my_world.title")
    assert_select ".lp-dash-nav.is-v4 .lp-dash-nav__link.is-active", text: /Mountain/i
  end

  test "show query count stays equal with one vs five journeys" do
    seed_climb!(@user, area_key: "self", title: "One climb", today_mission: "Battle one")
    warm_world_lookups!

    one_queries = count_world_data_queries { get world_path }
    assert_response :success

    %w[career purpose money learning].each_with_index do |area_key, i|
      seed_second_journey!(
        title: "Climb #{i + 2}",
        area_key: area_key,
        battle_title: "Battle #{i + 2}"
      )
    end
    warm_world_lookups!

    five_queries = count_world_data_queries { get world_path }
    assert_response :success
    assert_equal 5, @user.life_journeys.active.count
    assert_equal one_queries, five_queries,
                 "expected flat journey queries (1-journey=#{one_queries}, 5-journey=#{five_queries})"
  end

  test "focus sets journey to focus 1 and redirects to its mountain" do
    first = seed_climb!(@user, area_key: "self", title: "First", today_mission: "A")
    second = seed_second_journey!(title: "Second", area_key: "career", battle_title: "B")
    assert_equal 1, first.focus_position
    assert_nil second.focus_position

    patch focus_world_path, params: { journey_id: second.id }
    assert_redirected_to life_journey_path(second)
    assert_nil flash[:notice]
    assert_nil flash[:alert]
    assert_equal 1, second.reload.focus_position
    assert_nil first.reload.focus_position
  end

  test "focus with another users journey returns 404" do
    seed_climb!(@user, area_key: "self", title: "Mine", today_mission: "A")
    other = users(:two)
    other.update!(planning_version: 2, onboarding_completed_at: Time.current)
    foreign = seed_climb!(other, area_key: "career", title: "Theirs", today_mission: "B")

    patch focus_world_path, params: { journey_id: foreign.id }
    assert_response :not_found
  end

  test "focus with inactive journey returns 404" do
    seed_climb!(@user, area_key: "self", title: "Still climbing", today_mission: "A")
    inactive = seed_second_journey!(title: "Done", area_key: "career", battle_title: "B")
    inactive.update!(status: "completed", focus_position: nil)

    patch focus_world_path, params: { journey_id: inactive.id }
    assert_response :not_found
  end

  test "mountain v4 renders the my world corner button" do
    journey = seed_climb!(@user, area_key: "career", title: "Ship LifePoints", today_mission: "Write tests")
    goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: journey.id)
    goal.children.create!(
      user: @user, life_area: journey.life_area, life_journey: journey,
      horizon: "plan", title: "Main trail", position: 0
    )

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-rpg.is-v4-phone"
    assert_select "a.lp-trail__my-world-corner[href=?]", world_path
    assert_select "a.lp-trail__my-world-corner[aria-label=?]", I18n.t("my_world.open")
    assert_select ".lp-trail__my-world-corner__label", text: I18n.t("my_world.pill")
    assert_select ".lp-trail__summit .lp-trail__my-world-corner", count: 0
    assert_select ".lp-trail__summit .lp-trail__my-world-pill", count: 0
  end

  test "ring sheet wins match Battles::WinsByJourney" do
    travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
      journey = seed_climb!(@user, area_key: "self", title: "Sleep by 11", today_mission: "Lights out")
      battle = @user.strategy_goals.find_by!(horizon: "day", title: "Lights out", life_journey_id: journey.id)
      battle.update!(completed_at: Time.zone.local(2026, 8, 6, 9, 0, 0))

      empty = seed_second_journey!(title: "No wins yet", area_key: "career", battle_title: "Ship one")

      wins = Battles::WinsByJourney.call(user: @user)
      assert_equal 1, wins[journey.id]
      assert_equal 0, wins[empty.id].to_i

      get world_path
      assert_response :success
      assert_select ".lp-my-world-sheet[data-ring=me] .lp-my-world-sheet__mtn-meta",
                    text: I18n.t("my_world.battles_won", count: 1)
      assert_select ".lp-my-world-sheet[data-ring=friends_work] .lp-my-world-sheet__mtn-title",
                    text: empty.title
      assert_select ".lp-my-world-sheet[data-ring=friends_work] .lp-my-world-sheet__mtn-meta", count: 0
      assert_select ".lp-my-world-sheet[data-ring=me] .lp-my-world-sheet__mtn-now",
                    text: I18n.t("my_world.open_now")
    end
  end

  test "infinity sheet has hint and no add button" do
    seed_climb!(@user, area_key: "self", title: "Me climb", today_mission: "A")

    get world_path
    assert_response :success
    assert_select ".lp-my-world-list__row[data-ring=infinity]"
    assert_select ".lp-my-world-sheet[data-ring=infinity] .lp-my-world-sheet__hint",
                  text: I18n.t("my_world.rings.infinity.hint")
    assert_select ".lp-my-world-sheet[data-ring=infinity] .lp-my-world-sheet__pill", count: 0
    assert_select ".lp-my-world-sheet[data-ring=infinity] .lp-my-world-sheet__mtn.is-add", count: 0
    assert_select ".lp-my-world-sheet[data-ring=family_love] .lp-my-world-sheet__pill",
                  text: I18n.t("my_world.add_goal")
  end

  private

  def seed_second_journey!(title:, area_key:, battle_title:)
    LifeAreas::Select.call(user: @user, keys: [ area_key ])
    area = @user.life_areas.v2_selected.find_by!(key: area_key)
    journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: title,
      ideal_scene: "Ideal #{title}",
      current_reality: "Present #{title}",
      next_win: "Next #{title}",
      closer_percent: 20
    )
    goal = @user.strategy_goals.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "goal",
      title: title,
      position: 0
    )
    plan = goal.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Plan #{title}", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Camp #{title}", position: 0
    )
    project.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "day", title: battle_title, scheduled_on: Date.current, position: 0
    )
    journey
  end

  def warm_world_lookups!
    Battles::WinsByJourney.call(user: @user)
    current_user_journeys = @user.life_journeys.active.includes(:life_area).order(:id).to_a
    current_user_journeys.each { |j| j.life_area.world_ring }
  end

  def count_world_data_queries
    queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:cached]
      next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"
      next if payload[:sql].blank?

      sql = payload[:sql]
      next unless sql.match?(/life_journeys|life_areas|strategy_goals|daily_todos/i)

      queries += 1
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    queries
  end
end
